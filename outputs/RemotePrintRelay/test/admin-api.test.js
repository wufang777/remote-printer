import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import request from 'supertest';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { RelayStore } from '../src/relay-store.js';

test('administrator can log in with account and password then manage activation codes', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-admin-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const previousUsername = process.env.ADMIN_USERNAME;
  const previousPassword = process.env.ADMIN_PASSWORD;
  process.env.ADMIN_USERNAME = 'local-admin';
  process.env.ADMIN_PASSWORD = 'local-password';
  t.after(() => {
    if (previousUsername === undefined) delete process.env.ADMIN_USERNAME; else process.env.ADMIN_USERNAME = previousUsername;
    if (previousPassword === undefined) delete process.env.ADMIN_PASSWORD; else process.env.ADMIN_PASSWORD = previousPassword;
  });

  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });
  const authorization = `Basic ${Buffer.from('local-admin:local-password').toString('base64')}`;
  await request(app).get('/admin/activation-codes').expect(401);
  await request(app).put('/admin/settings/activation-token').set('Authorization', authorization).send({ token: 'first-local-token' }).expect(200);
  const created = await request(app)
    .post('/admin/activation-codes/batch')
    .set('Authorization', authorization)
    .send({ label: '门店 A', count: 2, reusable: true })
    .expect(201);
  assert.equal(created.body.codes.length, 2);
  assert.equal(created.body.codes[0].label, '门店 A');
  const code = created.body.codes[0].code;
  await request(app).post(`/admin/activation-codes/${code}/disable`).set('Authorization', authorization).expect(200);
  const list = await request(app).get('/admin/activation-codes').set('Authorization', authorization).expect(200);
  assert.equal(list.body.codes.find((entry) => entry.code === code).disabled, true);
});

test('admin page is available', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-admin-page-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });
  const response = await request(app).get('/admin').expect(200);
  assert.match(response.text, /在线设备/);
  assert.match(response.text, /最近打印任务/);
});

test('changing the activation token only changes the key version of future codes', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-admin-settings-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  process.env.ADMIN_USERNAME = 'local-admin';
  process.env.ADMIN_PASSWORD = 'local-password';
  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });
  const authorization = `Basic ${Buffer.from('local-admin:local-password').toString('base64')}`;
  await request(app).put('/admin/settings/activation-token').set('Authorization', authorization).send({ token: 'first-local-token' }).expect(200);
  const first = await request(app).post('/admin/activation-codes').set('Authorization', authorization).send({ label: '旧密钥' }).expect(201);
  await request(app).put('/admin/settings/activation-token').set('Authorization', authorization).send({ token: 'second-local-token' }).expect(200);
  const second = await request(app).post('/admin/activation-codes').set('Authorization', authorization).send({ label: '新密钥' }).expect(201);
  assert.equal(first.body.keyVersion, 1);
  assert.equal(second.body.keyVersion, 2);
  const settings = await request(app).get('/admin/settings').set('Authorization', authorization).expect(200);
  assert.deepEqual(settings.body, { configured: true, keyVersion: 2, pageSize: 20, listFilter: 'active', listSort: 'created_desc' });
});

test('administrator can paginate, search and delete activation codes', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-admin-codes-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  process.env.ADMIN_USERNAME = 'local-admin';
  process.env.ADMIN_PASSWORD = 'local-password';
  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });
  const authorization = `Basic ${Buffer.from('local-admin:local-password').toString('base64')}`;
  await request(app).put('/admin/settings/activation-token').set('Authorization', authorization).send({ token: 'token' }).expect(200);
  await request(app).patch('/admin/settings').set('Authorization', authorization).send({ pageSize: 2 }).expect(200);
  const created = await request(app).post('/admin/activation-codes/batch').set('Authorization', authorization).send({ label: '门店分页', count: 3 }).expect(201);
  const page = await request(app).get('/admin/activation-codes?page=2&pageSize=2&query=门店').set('Authorization', authorization).expect(200);
  assert.equal(page.body.total, 3);
  assert.equal(page.body.codes.length, 1);
  await request(app).delete(`/admin/activation-codes/${created.body.codes[0].code}`).set('Authorization', authorization).expect(204);
  const afterDelete = await request(app).get('/admin/activation-codes?query=门店').set('Authorization', authorization).expect(200);
  assert.equal(afterDelete.body.total, 2);
});

test('administrator can view soft-deleted codes and filter by enabled state', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-admin-view-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  process.env.ADMIN_USERNAME = 'local-admin'; process.env.ADMIN_PASSWORD = 'local-password';
  const store = await RelayStore.create(join(directory, 'data'));
  const app = createApp({ store, uploadDirectory: join(directory, 'files') });
  const authorization = `Basic ${Buffer.from('local-admin:local-password').toString('base64')}`;
  await request(app).put('/admin/settings/activation-token').set('Authorization', authorization).send({ token: 'token' }).expect(200);
  const created = await request(app).post('/admin/activation-codes/batch').set('Authorization', authorization).send({ label: '客户 A', count: 2 }).expect(201);
  await request(app).post(`/admin/activation-codes/${created.body.codes[0].code}/disable`).set('Authorization', authorization).expect(200);
  await request(app).delete(`/admin/activation-codes/${created.body.codes[1].code}`).set('Authorization', authorization).expect(204);
  const disabled = await request(app).get('/admin/activation-codes?filter=disabled').set('Authorization', authorization).expect(200);
  assert.equal(disabled.body.total, 1);
  const deleted = await request(app).get('/admin/activation-codes?filter=deleted').set('Authorization', authorization).expect(200);
  assert.equal(deleted.body.total, 1);
  assert.equal(deleted.body.codes[0].code, created.body.codes[1].code);
});
