import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createHmac, randomUUID } from 'node:crypto';

export class RelayStore {
  static async create(directory) {
    await mkdir(directory, { recursive: true });
    return new RelayStore(directory);
  }

  constructor(directory) { this.directory = directory; this.devicesFile = join(directory, 'devices.json'); this.jobsFile = join(directory, 'jobs.json'); this.codesFile = join(directory, 'activation-codes.json'); this.settingsFile = join(directory, 'admin-settings.json'); }

  async activationSettings() { const settings = await this.#read(this.settingsFile, { keyVersion: 0, token: null, pageSize: 20, listFilter: 'active', listSort: 'created_desc' }); return { configured: Boolean(settings.token), keyVersion: settings.keyVersion, pageSize: settings.pageSize ?? 20, listFilter: settings.listFilter ?? 'active', listSort: settings.listSort ?? 'created_desc' }; }
  async setActivationToken(token) {
    if (!token?.trim()) throw new Error('INVALID_ACTIVATION_TOKEN');
    const settings = await this.#read(this.settingsFile, { keyVersion: 0, token: null, pageSize: 20 });
    settings.token = token.trim();
    settings.keyVersion += 1;
    await this.#write(this.settingsFile, settings);
    return { configured: true, keyVersion: settings.keyVersion };
  }
  async updateAdminSettings({ pageSize, listFilter, listSort }) {
    const settings = await this.#read(this.settingsFile, { keyVersion: 0, token: null, pageSize: 20, listFilter: 'active', listSort: 'created_desc' });
    if (pageSize !== undefined) settings.pageSize = Math.min(100, Math.max(1, Number(pageSize) || 20));
    if (['active', 'enabled', 'disabled', 'deleted'].includes(listFilter)) settings.listFilter = listFilter;
    if (['created_desc', 'created_asc', 'customer'].includes(listSort)) settings.listSort = listSort;
    await this.#write(this.settingsFile, settings);
    return this.activationSettings();
  }

  async createActivationCode({ label = '', expiresAt = null, reusable = false }) {
    const settings = await this.#read(this.settingsFile, { keyVersion: 0, token: null, pageSize: 20 });
    if (!settings.token) throw new Error('ACTIVATION_TOKEN_NOT_CONFIGURED');
    const codes = await this.#read(this.codesFile, []);
    const code = `RP-${createHmac('sha256', settings.token).update(randomUUID()).digest('hex').slice(0, 10).toUpperCase()}`;
    const item = { code, label, expiresAt, reusable, keyVersion: settings.keyVersion, disabled: false, usedBy: [], createdAt: new Date().toISOString() };
    codes.push(item); await this.#write(this.codesFile, codes); return item;
  }
  async setActivationCodeEnabled(code, enabled) { const codes = await this.#read(this.codesFile, []); const item = codes.find((entry) => entry.code === code); if (!item) throw new Error('CODE_NOT_FOUND'); item.disabled = !enabled; await this.#write(this.codesFile, codes); return item; }
  async listActivationCodes() { return await this.#read(this.codesFile, []); }
  async deleteActivationCode(code) { const codes = await this.#read(this.codesFile, []); const item = codes.find((entry) => entry.code === code); if (!item) throw new Error('CODE_NOT_FOUND'); item.deletedAt = new Date().toISOString(); item.disabled = true; await this.#write(this.codesFile, codes); }
  async disableActivationCode(code) { const codes = await this.#read(this.codesFile, []); const item = codes.find((entry) => entry.code === code); if (!item) throw new Error('CODE_NOT_FOUND'); item.disabled = true; await this.#write(this.codesFile, codes); return item; }
  async listJobs() { return await this.#read(this.jobsFile, []); }

  async registerDevice({ activationCode, deviceName }) {
    if (!activationCode?.trim() || !deviceName?.trim()) throw new Error('INVALID_DEVICE');
    const codes = await this.#read(this.codesFile, []);
    const activation = codes.find((entry) => entry.code === activationCode);
    if (!activation) throw new Error('INVALID_ACTIVATION_CODE');
    if (activation.disabled) throw new Error('ACTIVATION_CODE_DISABLED');
    if (activation.expiresAt && new Date(activation.expiresAt) < new Date()) throw new Error('ACTIVATION_CODE_EXPIRED');
    const devices = await this.#read(this.devicesFile, []);
    let device = devices.find((entry) => entry.activationCode === activationCode);
    if (device && !activation.reusable && device.deviceName !== deviceName) throw new Error('ACTIVATION_CODE_ALREADY_USED');
    if (!device) {
      device = { deviceId: `dev_${randomUUID()}`, activationCode, deviceName, accessToken: `test_${randomUUID()}`, printers: [] };
      devices.push(device);
      activation.usedBy.push(device.deviceId);
      await this.#write(this.codesFile, codes);
    }
    else { device.deviceName = deviceName; }
    await this.#write(this.devicesFile, devices);
    return device;
  }

  async savePrinters(deviceId, printers) { const devices = await this.#read(this.devicesFile, []); const device = devices.find((entry) => entry.deviceId === deviceId); if (!device) throw new Error('DEVICE_NOT_FOUND'); device.printers = printers; await this.#write(this.devicesFile, devices); }
  async getDevice(deviceId) { return (await this.#read(this.devicesFile, [])).find((entry) => entry.deviceId === deviceId); }
  async listDevices() { return await this.#read(this.devicesFile, []); }
  async getDeviceByToken(token) { return (await this.#read(this.devicesFile, [])).find((entry) => entry.accessToken === token); }

  async createJob({ deviceId, printerName, file, copies = 1 }) {
    const jobs = await this.#read(this.jobsFile, []);
    const job = { taskId: `print_${randomUUID()}`, deviceId, printerName, file, copies, status: 'queued', claimedBy: null, events: [], createdAt: new Date().toISOString() };
    jobs.push(job); await this.#write(this.jobsFile, jobs); return job;
  }

  async claimJobs(deviceId, maximum = 5) {
    const jobs = await this.#read(this.jobsFile, []);
    const claimed = jobs.filter((job) => job.deviceId === deviceId && job.claimedBy === null && job.status === 'queued').slice(0, maximum);
    claimed.forEach((job) => { job.claimedBy = deviceId; job.status = 'claimed'; });
    await this.#write(this.jobsFile, jobs); return claimed;
  }

  async getJob(taskId) { return (await this.#read(this.jobsFile, [])).find((entry) => entry.taskId === taskId); }
  async appendEvent(taskId, event) { const jobs = await this.#read(this.jobsFile, []); const job = jobs.find((entry) => entry.taskId === taskId); if (!job) throw new Error('JOB_NOT_FOUND'); job.events.push(event); job.status = event.status; await this.#write(this.jobsFile, jobs); return job; }
  async #read(file, fallback) { try { return JSON.parse(await readFile(file, 'utf8')); } catch { return fallback; } }
  async #write(file, value) { await writeFile(file, JSON.stringify(value, null, 2)); }
}
