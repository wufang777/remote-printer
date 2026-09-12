import { createHash } from 'node:crypto';
import { mkdir, readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import express from 'express';
import multer from 'multer';

const supportedCategories = {
  pdf: new Set(['.pdf']),
  image: new Set(['.jpg', '.jpeg', '.png']),
  office: new Set(['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.csv']),
  wps: new Set(['.wps', '.et', '.dps'])
};

export function createApp({ store, uploadDirectory, publicBaseURL = 'http://127.0.0.1:17880' }) {
  const app = express();
  const upload = multer({ dest: uploadDirectory, limits: { fileSize: 25 * 1024 * 1024 } });
  app.use(express.json());

  app.get('/admin', (_req, res) => res.sendFile(resolve('src/admin.html')));
  app.get('/admin/activation-codes', adminOnly, async (_req, res) => res.json({ codes: await store.listActivationCodes() }));
  app.post('/admin/activation-codes', adminOnly, async (req, res) => res.status(201).json(await store.createActivationCode(req.body ?? {})));
  app.post('/admin/activation-codes/batch', adminOnly, async (req, res) => { const count = Math.min(100, Math.max(1, Number(req.body?.count) || 1)); const codes = await Promise.all(Array.from({ length: count }, () => store.createActivationCode(req.body ?? {}))); res.status(201).json({ codes }); });
  app.post('/admin/activation-codes/:code/enable', adminOnly, async (req, res) => res.json(await store.setActivationCodeEnabled(req.params.code, true)));
  app.post('/admin/activation-codes/:code/disable', adminOnly, async (req, res) => { try { res.json(await store.disableActivationCode(req.params.code)); } catch { res.status(404).json(error('CODE_NOT_FOUND', '找不到注册码。')); } });
  app.get('/admin/devices', adminOnly, async (_req, res) => res.json({ devices: await store.listDevices() }));
  app.get('/admin/jobs', adminOnly, async (_req, res) => res.json({ jobs: (await store.listJobs()).slice(-100).reverse() }));

  app.get('/', (_req, res) => res.json({ name: '本地远程打印测试中转站', status: 'online', submit: 'POST /sender/jobs', jobStatus: 'GET /sender/jobs/:taskId' }));
  app.get('/sender/jobs', (_req, res) => res.json({ message: '此接口用于 POST multipart/form-data 上传文件；请使用本地软件、curl 或 Postman 调用。' }));
  app.get('/sender/devices', async (_req, res) => {
    const devices = await store.listDevices();
    res.json({ devices: devices.map(({ deviceId, deviceName }) => ({ deviceId, deviceName })) });
  });
  app.get('/sender/devices/:deviceId/printers', async (req, res) => {
    const device = await store.getDevice(req.params.deviceId);
    if (!device) return res.status(404).json(error('DEVICE_NOT_FOUND', '找不到目标设备。'));
    return res.json({ printers: device.printers.map(({ name, isOnline, isDefault }) => ({ name, isOnline, isDefault })) });
  });

  app.post('/v1/devices/register', async (req, res) => {
    try {
      const device = await store.registerDevice(req.body);
      res.json({ deviceId: device.deviceId, accessToken: device.accessToken, expiresAt: '2030-01-01T00:00:00Z', pollIntervalSeconds: 10 });
    } catch { res.status(400).json(error('INVALID_DEVICE', '请填写注册码和设备名称。')); }
  });

  app.put('/v1/devices/:deviceId/printers', async (req, res) => {
    const device = await authenticatedDevice(req, store);
    if (!device || device.deviceId !== req.params.deviceId) return res.status(401).json(error('UNAUTHORIZED', '设备令牌无效。'));
    await store.savePrinters(device.deviceId, Array.isArray(req.body.printers) ? req.body.printers : []);
    res.status(204).end();
  });

  app.post('/v1/devices/:deviceId/print-jobs:claim', async (req, res) => {
    const device = await authenticatedDevice(req, store);
    if (!device || device.deviceId !== req.params.deviceId) return res.status(401).json(error('UNAUTHORIZED', '设备令牌无效。'));
    const jobs = await store.claimJobs(device.deviceId, Math.min(Number(req.body.maxJobs) || 5, 5));
    res.json({ jobs: jobs.map((job) => ({ taskId: job.taskId, printerName: job.printerName, contentType: contentType(job.file.fileName), file: { downloadUrl: `${publicBaseURL}/files/${job.taskId}/${encodeURIComponent(job.file.fileName)}`, sha256: job.file.sha256, fileName: job.file.fileName, expiresAt: '2030-01-01T00:00:00Z' }, printOptions: { copies: job.copies, duplex: 'none', paperSize: 'A4' }, requestedAt: job.createdAt })) });
  });

  app.get('/files/:taskId/:fileName', async (req, res) => {
    const job = await store.getJob(req.params.taskId);
    if (!job || job.file.fileName !== req.params.fileName || !job.claimedBy) return res.status(404).end();
    res.sendFile(resolve(uploadDirectory, job.file.relativePath));
  });

  app.post('/v1/devices/:deviceId/print-jobs/:taskId/events', async (req, res) => {
    const device = await authenticatedDevice(req, store);
    const job = await store.getJob(req.params.taskId);
    if (!device || device.deviceId !== req.params.deviceId || !job || job.claimedBy !== device.deviceId) return res.status(401).json(error('UNAUTHORIZED', '设备令牌或任务无效。'));
    await store.appendEvent(job.taskId, { ...req.body, occurredAt: req.body.occurredAt || new Date().toISOString() });
    res.status(204).end();
  });

  app.post('/sender/jobs', upload.single('file'), async (req, res) => {
    try {
      const { deviceId, printerName, copies = '1' } = req.body;
      if (!req.file || !fileCategory(req.file.originalname)) return res.status(400).json(error('INVALID_FILE', '仅支持 PDF、图片、Office 或 WPS 文档。'));
      const device = await store.getDevice(deviceId);
      if (!device) return res.status(404).json(error('DEVICE_NOT_FOUND', '找不到目标设备。'));
      if (!device.printers.some((printer) => printer.name === printerName && printer.isOnline)) return res.status(400).json(error('PRINTER_NOT_FOUND', '目标打印机不可用。'));
      await mkdir(uploadDirectory, { recursive: true });
      const data = await readFile(req.file.path);
      const job = await store.createJob({ deviceId, printerName, copies: Number.parseInt(copies, 10) || 1, file: { fileName: req.file.originalname, sha256: createHash('sha256').update(data).digest('hex'), relativePath: req.file.filename } });
      return res.status(201).json({ taskId: job.taskId, status: 'queued' });
    } catch (cause) { return res.status(500).json(error('INTERNAL_ERROR', '无法创建打印任务。')); }
  });

  app.get('/sender/jobs/:taskId', async (req, res) => { const job = await store.getJob(req.params.taskId); return job ? res.json(job) : res.status(404).json(error('JOB_NOT_FOUND', '找不到任务。')); });
  return app;
}

function error(code, message) { return { error: { code, message } }; }
function adminOnly(req, res, next) { const token = process.env.ADMIN_API_TOKEN; if (!token || req.get('Authorization') !== `Bearer ${token}`) return res.status(401).json(error('UNAUTHORIZED', '管理员密钥无效。')); next(); }
async function authenticatedDevice(req, store) { const token = req.get('Authorization')?.replace(/^Bearer\s+/, ''); return token ? store.getDeviceByToken(token) : undefined; }
function contentType(fileName) { return fileCategory(fileName); }
function fileCategory(fileName) {
  const extension = extname(fileName).toLowerCase();
  return Object.entries(supportedCategories).find(([, extensions]) => extensions.has(extension))?.[0];
}
