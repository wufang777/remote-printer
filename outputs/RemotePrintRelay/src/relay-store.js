import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';

export class RelayStore {
  static async create(directory) {
    await mkdir(directory, { recursive: true });
    return new RelayStore(directory);
  }

  constructor(directory) { this.directory = directory; this.devicesFile = join(directory, 'devices.json'); this.jobsFile = join(directory, 'jobs.json'); this.codesFile = join(directory, 'activation-codes.json'); }

  async createActivationCode({ label = '', expiresAt = null, reusable = false, keyVersion = 1 }) { const codes = await this.#read(this.codesFile, []); const code = `RP-${randomUUID().split('-')[0].toUpperCase()}`; const item = { code, label, expiresAt, reusable, keyVersion, disabled: false, usedBy: [], createdAt: new Date().toISOString() }; codes.push(item); await this.#write(this.codesFile, codes); return item; }
  async setActivationCodeEnabled(code, enabled) { const codes = await this.#read(this.codesFile, []); const item = codes.find((entry) => entry.code === code); if (!item) throw new Error('CODE_NOT_FOUND'); item.disabled = !enabled; await this.#write(this.codesFile, codes); return item; }
  async listActivationCodes() { return await this.#read(this.codesFile, []); }
  async disableActivationCode(code) { const codes = await this.#read(this.codesFile, []); const item = codes.find((entry) => entry.code === code); if (!item) throw new Error('CODE_NOT_FOUND'); item.disabled = true; await this.#write(this.codesFile, codes); return item; }
  async listJobs() { return await this.#read(this.jobsFile, []); }

  async registerDevice({ activationCode, deviceName }) {
    if (!activationCode?.trim() || !deviceName?.trim()) throw new Error('INVALID_DEVICE');
    const devices = await this.#read(this.devicesFile, []);
    let device = devices.find((entry) => entry.activationCode === activationCode);
    if (!device) { device = { deviceId: `dev_${randomUUID()}`, activationCode, deviceName, accessToken: `test_${randomUUID()}`, printers: [] }; devices.push(device); }
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
