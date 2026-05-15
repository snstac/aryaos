#!/usr/bin/env node
/**
 * Patch CloudTAK-SA api/web for deployment under /cloudtak/ on AryaOS.
 * SPDX-License-Identifier: Apache-2.0
 */
import fs from 'node:fs';
import path from 'node:path';

const webRoot = process.argv[2] || process.cwd();
const base = '/cloudtak/';

function patch(file, ...replacements) {
    const p = path.join(webRoot, file);
    let s = fs.readFileSync(p, 'utf8');
    const before = s;
    for (const [from, to] of replacements) {
        s = s.replace(from, to);
    }
    if (s === before) {
        console.warn(`patch-aryaos-subpath: no changes in ${file}`);
    }
    fs.writeFileSync(p, s);
    console.log(`patched ${file}`);
}

// Vite asset base
const vitePath = 'vite.config.ts';
let vite = fs.readFileSync(path.join(webRoot, vitePath), 'utf8');
if (!vite.includes('base:')) {
    vite = vite.replace('const res = {', `const res = {\n    base: '${base}',`);
    fs.writeFileSync(path.join(webRoot, vitePath), vite);
    console.log(`patched ${vitePath}`);
}

patch(
    'src/router.ts',
    ['createWebHistory()', 'createWebHistory(import.meta.env.BASE_URL)'],
);

patch(
    'src/std.ts',
    [
        'baseUrl: self.location.origin',
        "baseUrl: `${self.location.origin}${import.meta.env.BASE_URL}`.replace(/\\/$/, '')",
        "url = new URL(String(self.location.origin).replace(/\\/$/, '') + url);",
        "url = new URL(`${String(self.location.origin).replace(/\\/$/, '')}${import.meta.env.BASE_URL || '/'}`.replace(/\\/$/, '') + String(url));",
    ],
);

patch(
    'src/base/service-worker.ts',
    [
        'await fetch(`/.vite/manifest.json?ts=${Date.now()}`, {',
        'await fetch(`${import.meta.env.BASE_URL}.vite/manifest.json?ts=${Date.now()}`, {',
    ],
    [
        '`/sw.js?v=${encodeURIComponent(version)}&build=${encodeURIComponent(buildId)}`',
        '`${import.meta.env.BASE_URL}sw.js?v=${encodeURIComponent(version)}&build=${encodeURIComponent(buildId)}`',
    ],
);

patch(
    'src/App.vue',
    ["window.location.href = '/login'", "window.location.href = `${import.meta.env.BASE_URL}login`"],
    [
        "window.location.href = `/login?redirect=${encodeURIComponent(window.location.pathname)}`",
        "window.location.href = `${import.meta.env.BASE_URL}login?redirect=${encodeURIComponent(window.location.pathname)}`",
    ],
);

patch(
    'src/components/Login.vue',
    ["return '/CloudTAKLogoText.svg'", "return `${import.meta.env.BASE_URL}CloudTAKLogoText.svg`"],
);

const indexPath = path.join(webRoot, 'index.html');
if (fs.existsSync(indexPath)) {
    let index = fs.readFileSync(indexPath, 'utf8');
    if (index.includes('href="/api/manifest.webmanifest"')) {
        index = index.replace(
            'href="/api/manifest.webmanifest"',
            'href="/cloudtak/api/manifest.webmanifest"',
        );
        fs.writeFileSync(indexPath, index);
        console.log('patched index.html');
    }
}

console.log('patch-aryaos-subpath: done');
