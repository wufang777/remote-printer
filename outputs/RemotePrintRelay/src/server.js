import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from './app.js';
import { RelayStore } from './relay-store.js';

const projectDirectory = dirname(dirname(fileURLToPath(import.meta.url)));
const dataDirectory = join(projectDirectory, 'data');
const uploadDirectory = join(dataDirectory, 'files');
await mkdir(uploadDirectory, { recursive: true });
const store = await RelayStore.create(dataDirectory);
const app = createApp({ store, uploadDirectory, publicBaseURL: process.env.PUBLIC_BASE_URL ?? 'http://127.0.0.1:17880' });
const port = Number(process.env.PORT ?? 17880);
const host = process.env.HOST ?? '127.0.0.1';
app.listen(port, host, () => console.log(`远程打印中转站已启动：http://${host}:${port}`));
