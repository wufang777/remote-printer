import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { RelayStore } from '../src/relay-store.js';

test('client can register, synchronize printers, claim a job and report an event', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-client-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files'), publicBaseURL: 'http://127.0.0.1:17880' });
  const registration = await request(app).post('/v1/devices/register').send({ activationCode: 'RP-1', deviceName: 'Test Mac', platform: 'macOS', appVersion: '0.3.0', osVersion: '14.0' }).expect(200);
  const { deviceId, accessToken } = registration.body;
  await request(app).put(`/v1/devices/${deviceId}/printers`).set('Authorization', `Bearer ${accessToken}`).send({ printers: [{ name: 'Office', isOnline: true, isDefault: true }] }).expect(204);
  const file = join(directory, 'order.pdf');
  await writeFile(file, 'PDF');
  await request(app).post('/sender/jobs').field('deviceId', deviceId).field('printerName', 'Office').attach('file', file).expect(201);

  const claim = await request(app).post(`/v1/devices/${deviceId}/print-jobs:claim`).set('Authorization', `Bearer ${accessToken}`).send({ maxJobs: 5, availablePrinters: ['Office'] }).expect(200);
  assert.equal(claim.body.jobs.length, 1);
  assert.equal(claim.body.jobs[0].printerName, 'Office');
  await request(app).post(`/v1/devices/${deviceId}/print-jobs/${claim.body.jobs[0].taskId}/events`).set('Authorization', `Bearer ${accessToken}`).send({ status: 'succeeded', occurredAt: '2030-01-01T00:00:00Z' }).expect(204);
  const stored = await store.getJob(claim.body.jobs[0].taskId);
  assert.equal(stored.status, 'succeeded');
});
