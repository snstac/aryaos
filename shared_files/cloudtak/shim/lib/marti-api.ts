import http from 'node:http';
import https from 'node:https';
import express from 'express';
import type { Request } from 'express';
import { rateLimit } from 'express-rate-limit';
import CoTRouter from './cot-router.js';
import CertificateAuthority from './ca.js';
import { attachFauxCloudTakRoutes, verifyMartiBasicAuth } from './faux-cloudtak-api.js';

const DEFAULT_GROUP = {
    name: '__ANON__',
    direction: 'IN',
    created: new Date(0).toISOString(),
    type: 'SYSTEM',
    bitpos: 1,
    active: true,
    description: 'Default group'
};

function parseBasicAuth(req: Request): { username: string; password: string } | undefined {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith('Basic ')) return undefined;

    const encoded = auth.slice('Basic '.length).trim();
    const raw = Buffer.from(encoded, 'base64').toString('utf8');
    const split = raw.indexOf(':');
    if (split === -1) return undefined;

    return {
        username: raw.slice(0, split),
        password: raw.slice(split + 1)
    };
}

export function createMartiApp(args: {
    ca: CertificateAuthority;
    router: CoTRouter;
}): express.Application {
    const app = express();
    attachFauxCloudTakRoutes(app);
    app.use(express.json({ limit: '5mb' }));
    app.use(express.text({ type: ['application/pkcs10', 'application/octet-stream', 'text/plain'], limit: '2mb' }));
    const credentialsLimiter = rateLimit({
        windowMs: 60_000,
        max: 30,
        standardHeaders: 'draft-7',
        legacyHeaders: false,
        message: { message: 'Rate limit exceeded' }
    });

    app.get('/Marti/api/version', (req, res) => {
        res.json({ version: 'CloudTAK-Shim/0.1.0' });
    });

    app.get('/files/api/config', (req, res) => {
        res.json({ uploadSizeLimit: 250000000 });
    });

    app.get('/Marti/api/files/config', (req, res) => {
        res.json({ uploadSizeLimit: 250000000 });
    });

    app.get('/Marti/api/groups/all', (req, res) => {
        res.json({
            version: '3',
            type: 'com.bbn.marti.remote.groups.Group',
            data: [DEFAULT_GROUP]
        });
    });

    app.put('/Marti/api/groups/active', (req, res) => {
        res.status(200).json({
            version: '3',
            type: 'com.bbn.marti.remote.groups.Group',
            data: Array.isArray(req.body) ? req.body : [DEFAULT_GROUP]
        });
    });

    app.get('/Marti/api/groups/groupCacheEnabled', (req, res) => {
        res.json(false);
    });

    app.get('/Marti/api/contacts/all', (req, res) => {
        res.json(args.router.listContacts());
    });

    app.get('/Marti/api/clientEndPoints', (req, res) => {
        res.json({
            version: '3',
            type: 'com.bbn.marti.remote.ClientEndpoint',
            data: args.router.listClientEndpoints()
        });
    });

    app.get('/Marti/api/tls/config', (req, res) => {
        res.type('application/xml');
        res.send('<ns2:certificateConfig><nameEntries><nameEntry name="O" value="SNSTAC"/><nameEntry name="OU" value="CloudTAK Shim"/></nameEntries></ns2:certificateConfig>');
    });

    app.post('/Marti/api/tls/signClient/v2', credentialsLimiter, (req, res) => {
        if (!verifyMartiBasicAuth(req)) {
            res.status(401).json({ message: 'Basic auth required or invalid credentials' });
            return;
        }

        if (typeof req.body !== 'string' || !req.body.includes('BEGIN CERTIFICATE REQUEST')) {
            res.status(400).json({ message: 'CSR payload required' });
            return;
        }

        try {
            const signedPem = args.ca.signCSR(req.body);
            res.json({
                signedCert: CoTRouter.pemCore(signedPem),
                ca0: CoTRouter.pemCore(args.ca.getCAPem())
            });
        } catch (err) {
            res.status(400).json({ message: err instanceof Error ? err.message : String(err) });
        }
    });

    app.post('/Marti/api/tls/config', credentialsLimiter, (req, res) => {
        if (!verifyMartiBasicAuth(req)) {
            res.status(401).json({ message: 'Basic auth required or invalid credentials' });
            return;
        }

        const basic = parseBasicAuth(req);
        const signed = args.ca.signClient(basic?.username || 'cloudtak-user');
        res.json(signed);
    });

    return app;
}

export default function startMartiAPI(args: {
    ca: CertificateAuthority;
    router: CoTRouter;
    port: number;
}): https.Server {
    const app = createMartiApp(args);
    const creds = args.ca.getServerCredentials();
    const server = https.createServer({
        cert: creds.cert,
        key: creds.key,
        ca: creds.ca
    }, app);

    server.listen(args.port, '0.0.0.0', () => {
        console.log(`ok - Marti API listening on ${args.port}`);
    });

    return server;
}

export function startMartiHTTP(args: {
    ca: CertificateAuthority;
    router: CoTRouter;
    port: number;
    host?: string;
}): http.Server {
    const app = createMartiApp(args);
    const host = args.host ?? '127.0.0.1';
    const server = http.createServer(app);

    server.listen(args.port, host, () => {
        console.log(`ok - Marti API (HTTP, reverse-proxy) listening on ${host}:${args.port}`);
    });

    return server;
}
