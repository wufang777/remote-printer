import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { RelayStore } from '../src/relay-store.js';

test('a job can only be claimed once by its target device', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-store-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const store = await RelayStore.create(directory);
  await store.setActivationToken('test-token');
  const code = await store.createActivationCode({ label: '测试设备' });
  const device = await store.registerDevice({ activationCode: code.code, deviceName: 'Test Mac' });
  await store.savePrinters(device.deviceId, [{ name: 'Office', isOnline: true }]);
  await store.createJob({ deviceId: device.deviceId, printerName: 'Office', file: { fileName: 'order.pdf', sha256: 'a'.repeat(64), relativePath: 'files/order.pdf' } });

  assert.equal((await store.claimJobs(device.deviceId)).length, 1);
  assert.equal((await store.claimJobs(device.deviceId)).length, 0);
});
