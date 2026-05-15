import path from 'node:path';
import process from 'node:process';
import CertificateAuthority from './lib/ca.js';
import CoTRouter from './lib/cot-router.js';
import startTakServer from './lib/tak-server.js';
import startMartiAPI, { startMartiHTTP } from './lib/marti-api.js';
import startInjectionAPI from './lib/injection-api.js';

const TAK_PORT = Number(process.env.SA_SHIM_TAK_PORT || 8089);
const MARTI_PORT = Number(process.env.SA_SHIM_MARTI_PORT || 8443);
const MARTI_HTTP_PORT = Number(process.env.SA_SHIM_MARTI_HTTP_PORT || 18443);
// Listen on all interfaces in-container; compose publishes 127.0.0.1:18443 on the host only.
const MARTI_HTTP_HOST = process.env.SA_SHIM_MARTI_HTTP_HOST || '0.0.0.0';
const INJECT_PORT = Number(process.env.SA_SHIM_INJECT_PORT || 8080);
const CERT_DIR = process.env.SA_SHIM_CERT_DIR || path.resolve(process.cwd(), 'certs');

const startedAt = Date.now();
const ca = new CertificateAuthority(CERT_DIR);
const router = new CoTRouter();

const takServer = startTakServer({
    ca,
    router,
    port: TAK_PORT
});

const martiServer = startMartiAPI({
    ca,
    router,
    port: MARTI_PORT
});

const martiHttpServer = startMartiHTTP({
    ca,
    router,
    port: MARTI_HTTP_PORT,
    host: MARTI_HTTP_HOST
});

const injectionServer = startInjectionAPI({
    router,
    port: INJECT_PORT,
    startedAt
});

async function shutdown(signal: string): Promise<void> {
    console.log(`ok - received ${signal} - shutting down`);

    await Promise.all([
        new Promise<void>((resolve) => takServer.close(() => resolve())),
        new Promise<void>((resolve) => martiServer.close(() => resolve())),
        new Promise<void>((resolve) => martiHttpServer.close(() => resolve())),
        new Promise<void>((resolve) => injectionServer.close(() => resolve()))
    ]);

    process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
