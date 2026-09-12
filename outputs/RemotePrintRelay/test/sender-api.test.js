import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { RelayStore } from '../src/relay-store.js';

test('uploads a supported file for a synchronized printer', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-api-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const fixture = join(directory, 'order.pdf');
  await writeFile(fixture, 'PDF test');
  const store = await RelayStore.create(join(directory, 'data'));
  await store.setActivationToken('test-token');
  const code = await store.createActivationCode({ label: '测试设备' });
  const device = await store.registerDevice({ activationCode: code.code, deviceName: 'Test Mac' });
  await store.savePrinters(device.deviceId, [{ name: 'Office', isOnline: true }]);

  const response = await request(createApp({ store, uploadDirectory: join(directory, 'files') }))
    .post('/sender/jobs').field('deviceId', device.deviceId).field('printerName', 'Office').attach('file', fixture);

  assert.equal(response.status, 201);
  assert.equal(response.body.status, 'queued');
  assert.ok(response.body.taskId.startsWith('print_'));
});

test('uploads an Office document for a synchronized printer', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-office-api-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const fixture = join(directory, '报价单.docx');
  await writeFile(fixture, 'Office test');
  const store = await RelayStore.create(join(directory, 'data'));
  await store.setActivationToken('test-token');
  const code = await store.createActivationCode({ label: '测试设备' });
  const device = await store.registerDevice({ activationCode: code.code, deviceName: 'Test Mac' });
  await store.savePrinters(device.deviceId, [{ name: 'Office', isOnline: true }]);

  const response = await request(createApp({ store, uploadDirectory: join(directory, 'files') }))
    .post('/sender/jobs').field('deviceId', device.deviceId).field('printerName', 'Office').attach('file', fixture);

  assert.equal(response.status, 201);
  assert.equal(response.body.status, 'queued');
});
