import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { RelayStore } from '../src/relay-store.js';

test('disabled or already-used one-time activation code cannot register another device', async (t) => {
  const directory = await mkdtemp(join(tmpdir(), 'relay-codes-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const store = await RelayStore.create(directory);
  await store.setActivationToken('test-token');
  const oneTime = await store.createActivationCode({ label: '本地测试', reusable: false });

  const first = await store.registerDevice({ activationCode: oneTime.code, deviceName: 'Mac One' });
  assert.equal(first.deviceName, 'Mac One');
  await assert.rejects(
    store.registerDevice({ activationCode: oneTime.code, deviceName: 'Mac Two' }),
    { message: 'ACTIVATION_CODE_ALREADY_USED' }
  );

  const disabled = await store.createActivationCode({ label: '禁用测试' });
  await store.disableActivationCode(disabled.code);
  await assert.rejects(
    store.registerDevice({ activationCode: disabled.code, deviceName: 'Mac Three' }),
    { message: 'ACTIVATION_CODE_DISABLED' }
  );
});
