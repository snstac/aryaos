/**
 * Minimal CloudTAK-compatible REST stubs for SPA + Marti shim (no full TAK Server).
 *
 * Matches default credentials documented in README (env overrides).
 *
 * SPDX-License-Identifier: Apache-2.0
 */
import crypto from 'node:crypto';
import express, { type Request, type Response } from 'express';

const LOGIN_USER =
    process.env.SA_SHIM_LOGIN_USER ?? process.env.SA_SHIM_BASIC_USER ?? 'cloudtak';
const LOGIN_PASSWORD =
    process.env.SA_SHIM_LOGIN_PASSWORD ?? process.env.SA_SHIM_BASIC_PASSWORD ?? 'cloudtak415';

const MAPLIBRE_FONT_BASE =
    process.env.SA_SHIM_FONT_PROXY_BASE ??
    'https://demotiles.maplibre.org/fonts';

function makeJwt(username: string): string {
    const exp = Math.floor(Date.now() / 1000) + 86400 * 365;
    const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ exp, sub: username, username })).toString(
        'base64url'
    );
    return `${header}.${payload}.`;
}

function configForKeys(keys: string): Record<string, unknown> {
    const list = keys
        .split(',')
        .map((k) => k.trim())
        .filter(Boolean);
    const out: Record<string, unknown> = {};
    const defaults: Record<string, unknown> = {
        'login::name': 'CloudTAK (AryaOS shim)',
        'login::logo': null,
        'login::signup': false,
        'login::forgot': false,
        'login::username': 'Username',
        'login::brand::enabled': 'default',
        'login::brand::logo': null,
        'login::background::enabled': false,
        'login::background::color': null,
        'oidc::enforced': false,
        'oidc::enabled': false,
        'oidc::discovery': '',
        'oidc::name': '',
        'oidc::logo': '',
        'passkey::enabled': false,
        'map::center': '-100,40',
        'map::zoom': 4,
        'map::pitch': 0,
        'map::bearing': 0,
        'map::basemap': null,
    };

    const want = list.length === 0 ? Object.keys(defaults) : list;
    for (const k of want) {
        if (k in defaults) {
            out[k] = defaults[k];
        }
    }
    return out;
}

/** Current server pseudo-state merged from PATCH (ephemeral until restart). */
let serverDraft: Record<string, unknown> = {
    status: 'configured',
    id: 'aryaos-shim',
    name: 'AryaOS CloudTAK shim',
};

export function attachFauxCloudTakRoutes(app: express.Application): void {
    const router = express.Router();

    router.use(express.json({ limit: '2mb' }));

    router.post('/login', (req: Request, res: Response): void => {
        const username = typeof req.body?.username === 'string' ? req.body.username : '';
        const password = typeof req.body?.password === 'string' ? req.body.password : '';
        if (username !== LOGIN_USER || password !== LOGIN_PASSWORD) {
            res.status(401).json({ message: 'Invalid username or password' });
            return;
        }
        res.json({ token: makeJwt(username) });
    });

    router.get('/config', (req: Request, res: Response): void => {
        const keys = typeof req.query.keys === 'string' ? req.query.keys : '';
        res.json(configForKeys(keys));
    });

    router.get('/server', (_req: Request, res: Response): void => {
        res.json({
            ...serverDraft,
            status: 'configured',
            url: typeof serverDraft.url === 'string' ? serverDraft.url : 'ssl://127.0.0.1:8089',
            api:
                typeof serverDraft.api === 'string' ? serverDraft.api : 'https://127.0.0.1:8443',
            webtak:
                typeof serverDraft.webtak === 'string'
                    ? serverDraft.webtak
                    : 'https://127.0.0.1:8443',
            username: typeof serverDraft.username === 'string' ? serverDraft.username : LOGIN_USER,
        });
    });

    router.patch('/server', (req: Request, res: Response): void => {
        serverDraft = { ...serverDraft, ...req.body, status: 'configured' };
        res.json(serverDraft);
    });

    router.get('/profile', (_req: Request, res: Response): void => {
        res.json({
            username: LOGIN_USER,
            email: `${LOGIN_USER}@localhost`,
            tak_callsign: process.env.SA_SHIM_CALLSIGN ?? 'CLOUDTAK-SHIM',
            roles: [{ id: '1', name: 'USER' }],
        });
    });

    router.get('/profile/overlay', (_req: Request, res: Response): void => {
        res.json({ total: 0, items: [] });
    });

    router.get('/basemap', (_req: Request, res: Response): void => {
        res.json({ total: 0, items: [] });
    });

    router.get(/^\/fonts\/([\s\S]+)$/, async (req: Request, res: Response) => {
        const pathAfterFonts = decodeURIComponent(req.params['0']);
        const slash = pathAfterFonts.lastIndexOf('/');
        if (slash < 0) {
            res.status(400).json({ message: 'Invalid fonts path' });
            return;
        }
        const fontstack = pathAfterFonts.slice(0, slash);
        const rangeFile = pathAfterFonts.slice(slash + 1);
        if (!/^\d+(?:-\d+)?\.pbf$/.test(rangeFile)) {
            res.status(400).json({ message: 'Invalid range file' });
            return;
        }
        const url = `${MAPLIBRE_FONT_BASE}/${encodeURIComponent(fontstack)}/${rangeFile}`;
        try {
            const upstream = await fetch(url);
            if (!upstream.ok) {
                res.status(upstream.status).send(await upstream.text());
                return;
            }
            const buf = Buffer.from(await upstream.arrayBuffer());
            res.status(200);
            res.setHeader('Content-Type', 'application/x-protobuf');
            res.setHeader('Cache-Control', 'public, max-age=86400');
            res.send(buf);
        } catch (err) {
            res.status(502).json({
                message: err instanceof Error ? err.message : 'font proxy failed',
            });
        }
    });

    app.use('/api', router);
}

/** Basic auth check for Marti TLS enrollment (shared with Express). */
export function verifyMartiBasicAuth(req: Request): boolean {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith('Basic ')) return false;
    const encoded = auth.slice('Basic '.length).trim();
    const raw = Buffer.from(encoded, 'base64').toString('utf8');
    const i = raw.indexOf(':');
    const u = i === -1 ? raw : raw.slice(0, i);
    const p = i === -1 ? '' : raw.slice(i + 1);
    const eu = process.env.SA_SHIM_BASIC_USER ?? LOGIN_USER;
    const ep = process.env.SA_SHIM_BASIC_PASSWORD ?? LOGIN_PASSWORD;
    const safe =
        typeof crypto.timingSafeEqual === 'function'
            ? (a: string, b: string) => {
                  const ab = Buffer.from(a);
                  const bb = Buffer.from(b);
                  if (ab.length !== bb.length) return false;
                  return crypto.timingSafeEqual(ab, bb);
              }
            : (a: string, b: string) => a === b;
    return safe(u, eu) && safe(p, ep);
}
