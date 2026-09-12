import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { RelayStore } from '../src/relay-store.js';

test('lists synchronized printers for a registered device', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-devices-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const store = await RelayStore.create(join(directory, 'data'));
  await store.setActivationToken('test-token');
  const code = await store.createActivationCode({ label: '测试设备' });
  const device = await store.registerDevice({ activationCode: code.code, deviceName: 'Test Mac' });
  await store.savePrinters(device.deviceId, [{ name: 'Office', isOnline: true, isDefault: true }]);
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });

  const devices = await request(app).get('/sender/devices').expect(200);
  assert.equal(devices.body.devices[0].deviceName, 'Test Mac');
  const printers = await request(app).get(`/sender/devices/${device.deviceId}/printers`).expect(200);
  assert.equal(printers.body.printers[0].name, 'Office');
});
