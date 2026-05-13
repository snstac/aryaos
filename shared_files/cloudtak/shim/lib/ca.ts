import fs from 'node:fs';
import path from 'node:path';
import forge from 'node-forge';

export type SignedClient = {
    cert: string;
    key: string;
    ca: string[];
};

function loadIfExists(file: string): string | undefined {
    return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : undefined;
}

function writeIfMissing(file: string, value: string): void {
    if (!fs.existsSync(file)) fs.writeFileSync(file, value, 'utf8');
}

function randomSerial(): string {
    return forge.util.bytesToHex(forge.random.getBytesSync(16));
}

export default class CertificateAuthority {
    readonly certDir: string;
    readonly caCertPath: string;
    readonly caKeyPath: string;
    readonly serverCertPath: string;
    readonly serverKeyPath: string;

    caCertPem: string;
    caKeyPem: string;
    serverCertPem: string;
    serverKeyPem: string;

    constructor(certDir: string) {
        this.certDir = certDir;
        this.caCertPath = path.join(certDir, 'ca.crt');
        this.caKeyPath = path.join(certDir, 'ca.key');
        this.serverCertPath = path.join(certDir, 'server.crt');
        this.serverKeyPath = path.join(certDir, 'server.key');

        fs.mkdirSync(certDir, { recursive: true });

        const existingCaCert = loadIfExists(this.caCertPath);
        const existingCaKey = loadIfExists(this.caKeyPath);

        if (!existingCaCert || !existingCaKey) {
            const keys = forge.pki.rsa.generateKeyPair({ bits: 2048 });
            const cert = forge.pki.createCertificate();
            cert.publicKey = keys.publicKey;
            cert.serialNumber = randomSerial();
            cert.validity.notBefore = new Date(Date.now() - 5 * 60 * 1000);
            cert.validity.notAfter = new Date(Date.now() + 10 * 365 * 24 * 60 * 60 * 1000);

            const subject = [
                { name: 'commonName', value: 'CloudTAK Shim CA' },
                { name: 'organizationName', value: 'SNSTAC' },
                { shortName: 'OU', value: 'CloudTAK Shim' }
            ];

            cert.setSubject(subject);
            cert.setIssuer(subject);
            cert.setExtensions([
                { name: 'basicConstraints', cA: true },
                { name: 'keyUsage', keyCertSign: true, cRLSign: true, digitalSignature: true },
                { name: 'subjectKeyIdentifier' }
            ]);
            cert.sign(keys.privateKey, forge.md.sha256.create());

            this.caCertPem = forge.pki.certificateToPem(cert);
            this.caKeyPem = forge.pki.privateKeyToPem(keys.privateKey);

            writeIfMissing(this.caCertPath, this.caCertPem);
            writeIfMissing(this.caKeyPath, this.caKeyPem);
        } else {
            this.caCertPem = existingCaCert;
            this.caKeyPem = existingCaKey;
        }

        const existingServerCert = loadIfExists(this.serverCertPath);
        const existingServerKey = loadIfExists(this.serverKeyPath);

        if (!existingServerCert || !existingServerKey) {
            const signed = this.signClient('cloudtak-shim-server', ['localhost'], true);
            this.serverCertPem = signed.cert;
            this.serverKeyPem = signed.key;
            writeIfMissing(this.serverCertPath, this.serverCertPem);
            writeIfMissing(this.serverKeyPath, this.serverKeyPem);
        } else {
            this.serverCertPem = existingServerCert;
            this.serverKeyPem = existingServerKey;
        }
    }

    getServerCredentials(): { cert: string; key: string; ca: string[] } {
        return {
            cert: this.serverCertPem,
            key: this.serverKeyPem,
            ca: [this.caCertPem]
        };
    }

    getCAPem(): string {
        return this.caCertPem;
    }

    signCSR(csrPem: string): string {
        const csr = forge.pki.certificationRequestFromPem(csrPem);
        if (!csr.verify()) throw new Error('Invalid CSR payload');
        if (!csr.publicKey) throw new Error('CSR missing public key');

        const cert = forge.pki.createCertificate();
        cert.publicKey = csr.publicKey;
        cert.serialNumber = randomSerial();
        cert.validity.notBefore = new Date(Date.now() - 5 * 60 * 1000);
        cert.validity.notAfter = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
        cert.setSubject(csr.subject.attributes);
        cert.setIssuer(forge.pki.certificateFromPem(this.caCertPem).subject.attributes);
        cert.setExtensions([
            { name: 'basicConstraints', cA: false },
            { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
            { name: 'extKeyUsage', clientAuth: true },
            { name: 'subjectKeyIdentifier' },
            { name: 'authorityKeyIdentifier', keyIdentifier: true }
        ]);

        cert.sign(forge.pki.privateKeyFromPem(this.caKeyPem), forge.md.sha256.create());
        return forge.pki.certificateToPem(cert);
    }

    signClient(commonName: string, dnsNames: string[] = [], serverAuth = false): SignedClient {
        const keys = forge.pki.rsa.generateKeyPair({ bits: 2048 });
        const cert = forge.pki.createCertificate();

        cert.publicKey = keys.publicKey;
        cert.serialNumber = randomSerial();
        cert.validity.notBefore = new Date(Date.now() - 5 * 60 * 1000);
        cert.validity.notAfter = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

        cert.setSubject([
            { name: 'commonName', value: commonName },
            { name: 'organizationName', value: 'SNSTAC' },
            { shortName: 'OU', value: 'CloudTAK Shim' }
        ]);
        cert.setIssuer(forge.pki.certificateFromPem(this.caCertPem).subject.attributes);

        const extensions: any[] = [
            { name: 'basicConstraints', cA: false },
            { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
            {
                name: 'extKeyUsage',
                clientAuth: !serverAuth,
                serverAuth
            },
            { name: 'subjectKeyIdentifier' },
            { name: 'authorityKeyIdentifier', keyIdentifier: true }
        ];

        if (dnsNames.length > 0) {
            extensions.push({
                name: 'subjectAltName',
                altNames: dnsNames.map((dns) => ({ type: 2, value: dns }))
            });
        }

        cert.setExtensions(extensions);
        cert.sign(forge.pki.privateKeyFromPem(this.caKeyPem), forge.md.sha256.create());

        return {
            cert: forge.pki.certificateToPem(cert),
            key: forge.pki.privateKeyToPem(keys.privateKey),
            ca: [this.caCertPem]
        };
    }
}
