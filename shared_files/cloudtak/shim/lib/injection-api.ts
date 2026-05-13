import http from 'node:http';
import express from 'express';
import type { Feature } from 'geojson';
import { CoTParser } from '@tak-ps/node-cot';
import CoTRouter from './cot-router.js';

export default function startInjectionAPI(args: {
    router: CoTRouter;
    port: number;
    startedAt: number;
}): http.Server {
    const app = express();

    app.use(express.json({ limit: '10mb' }));

    app.post('/api/cot', express.text({ type: '*/*', limit: '2mb' }), (req, res) => {
        if (typeof req.body !== 'string' || !req.body.includes('<event')) {
            res.status(400).json({ status: 400, message: 'Raw CoT XML body required' });
            return;
        }

        try {
            CoTParser.from_xml(req.body);
            args.router.inject(req.body);
            res.json({ status: 200, message: 'CoT injected' });
        } catch (err) {
            res.status(400).json({ status: 400, message: err instanceof Error ? err.message : String(err) });
        }
    });

    app.post('/api/cot/geojson', async (req, res) => {
        try {
            const feature = req.body as Feature;
            const normalized = {
                ...feature,
                id: feature.id !== undefined ? String(feature.id) : undefined
            };
            const cot = await CoTParser.from_geojson(normalized as never);
            const xml = CoTParser.to_xml(cot);
            args.router.inject(xml);
            res.json({ status: 200, message: 'GeoJSON converted and injected', xml });
        } catch (err) {
            res.status(400).json({ status: 400, message: err instanceof Error ? err.message : String(err) });
        }
    });

    app.get('/api/clients', (req, res) => {
        res.json({
            total: args.router.clients.size,
            items: args.router.listClients().map(({ send, ...client }) => client)
        });
    });

    app.get('/api/health', (req, res) => {
        res.json({
            status: 'ok',
            uptimeSec: Math.floor((Date.now() - args.startedAt) / 1000),
            clients: args.router.clients.size
        });
    });

    const server = app.listen(args.port, '0.0.0.0', () => {
        console.log(`ok - Injection API listening on ${args.port}`);
    });

    return server;
}
