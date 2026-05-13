import tls from 'node:tls';
import { randomUUID } from 'node:crypto';
import CoTRouter from './cot-router.js';
import { CoTParser } from '@tak-ps/node-cot';
import CertificateAuthority from './ca.js';

const MAX_BUFFER_SIZE = 8192;

function extractCotEvents(buffer: string): { events: string[]; remainder: string } {
    const events: string[] = [];
    let rest = buffer;

    while (true) {
        const start = rest.indexOf('<event');
        if (start === -1) return { events, remainder: rest.slice(-MAX_BUFFER_SIZE) };

        if (start > 0) rest = rest.slice(start);

        const end = rest.indexOf('</event>');
        if (end === -1) return { events, remainder: rest.slice(-MAX_BUFFER_SIZE) };

        const rawEvent = rest.slice(0, end + '</event>'.length);
        events.push(rawEvent);
        rest = rest.slice(end + '</event>'.length);
    }
}

function groupChangeCotXML(): string {
    const cot = CoTParser.from_xml(`
<event version="2.0" uid="CloudTAK-Shim-GroupChange" type="t-x-g-c" time="${new Date().toISOString()}" start="${new Date().toISOString()}" stale="${new Date(Date.now() + 3600000).toISOString()}">
  <point lat="0" lon="0" hae="9999999" ce="9999999" le="9999999" />
  <detail />
</event>`);
    return CoTParser.to_xml(cot);
}

function socketCommonName(cert: tls.PeerCertificate, fallback: string): string {
    const cnValue = cert?.subject?.CN;
    if (typeof cnValue === 'string') return cnValue;
    if (Array.isArray(cnValue) && cnValue.length) return cnValue[0];
    return fallback;
}

export default function startTakServer(args: {
    ca: CertificateAuthority;
    router: CoTRouter;
    port: number;
}): tls.Server {
    const creds = args.ca.getServerCredentials();

    const server = tls.createServer({
        cert: creds.cert,
        key: creds.key,
        ca: creds.ca,
        requestCert: true,
        rejectUnauthorized: true
    }, (socket) => {
        const id = randomUUID();
        const cert = socket.getPeerCertificate();
        const cn = socketCommonName(cert, `client-${id}`);
        const now = new Date().toISOString();

        args.router.addClient({
            id,
            uid: cn,
            callsign: cn,
            username: cn,
            team: 'Cyan',
            role: 'Team Member',
            connectedAt: now,
            lastStatus: now,
            send: (xml: string) => {
                if (!socket.destroyed) socket.write(xml);
            }
        });

        socket.write(groupChangeCotXML());

        let buffer = '';
        socket.on('data', async (chunk: Buffer) => {
            buffer += chunk.toString('utf8');
            const parsed = extractCotEvents(buffer);
            buffer = parsed.remainder;

            for (const eventXml of parsed.events) {
                await args.router.receive(eventXml, id);
            }
        });

        socket.on('close', () => {
            args.router.removeClient(id);
        });

        socket.on('error', () => {
            args.router.removeClient(id);
        });
    });

    server.listen(args.port, '0.0.0.0', () => {
        console.log(`ok - TAK TLS stream listening on ${args.port}`);
    });

    return server;
}
