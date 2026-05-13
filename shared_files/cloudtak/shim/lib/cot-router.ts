import { CoTParser } from '@tak-ps/node-cot';

export type ShimClient = {
    id: string;
    uid: string;
    callsign: string;
    username: string;
    team: string;
    role: string;
    connectedAt: string;
    lastStatus: string;
    send: (xml: string) => void;
};

function formatPemCore(pem: string): string {
    return pem
        .split('\n')
        .filter((line) => line && !line.includes('BEGIN') && !line.includes('END'))
        .join('\n');
}

export default class CoTRouter {
    readonly clients = new Map<string, ShimClient>();

    addClient(client: ShimClient): void {
        this.clients.set(client.id, client);
    }

    removeClient(id: string): void {
        this.clients.delete(id);
    }

    listClients(): ShimClient[] {
        return Array.from(this.clients.values()).map((client) => ({ ...client }));
    }

    listClientEndpoints(): Array<{ callsign: string; uid: string; username: string; team: string; role: string; lastStatus: string }> {
        return this.listClients().map((client) => ({
            callsign: client.callsign,
            uid: client.uid,
            username: client.username,
            team: client.team,
            role: client.role,
            lastStatus: client.lastStatus
        }));
    }

    listContacts(): Array<{ filterGroups: object; notes: string; callsign: string; team: string; role: string; takv: string; uid: string }> {
        return this.listClients().map((client) => ({
            filterGroups: {},
            notes: client.username,
            callsign: client.callsign,
            team: client.team,
            role: client.role,
            takv: 'CloudTAK Shim',
            uid: client.uid
        }));
    }

    touchClient(id: string, patch: Partial<Pick<ShimClient, 'uid' | 'callsign' | 'username' | 'team' | 'role'>> = {}): void {
        const current = this.clients.get(id);
        if (!current) return;

        this.clients.set(id, {
            ...current,
            ...patch,
            lastStatus: new Date().toISOString()
        });
    }

    async receive(xml: string, sourceClientId: string): Promise<void> {
        await this.captureClientIdentity(xml, sourceClientId);
        this.broadcast(xml, sourceClientId);
    }

    inject(xml: string): void {
        this.broadcast(xml);
    }

    broadcast(xml: string, excludeClientId?: string): void {
        for (const client of this.clients.values()) {
            if (excludeClientId && client.id === excludeClientId) continue;
            client.send(xml);
        }
    }

    async captureClientIdentity(xml: string, clientId: string): Promise<void> {
        try {
            const cot = CoTParser.from_xml(xml);
            const raw = cot.raw;
            const uid = raw.event._attributes.uid || `client-${clientId}`;
            const callsign = raw.event.detail?.contact?._attributes?.callsign || uid;
            const team = raw.event.detail?.__group?._attributes?.name || 'Cyan';
            const role = raw.event.detail?.__group?._attributes?.role || 'Team Member';
            this.touchClient(clientId, {
                uid,
                callsign,
                username: callsign,
                team,
                role
            });
        } catch {
            // Ignore parse failures for partial or malformed payloads
        }
    }

    static certCN(certPem: string): string | undefined {
        try {
            const match = certPem.match(/CN=([^\n,]+)/);
            return match?.[1]?.trim();
        } catch {
            return undefined;
        }
    }

    static pemCore(pem: string): string {
        return formatPemCore(pem);
    }
}
