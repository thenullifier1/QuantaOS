#!/data/data/com.termux/files/usr/bin/node
// patch-server.js — run once to add F-Droid proxy to server.js
// Usage: node patch-server.js

const fs = require('fs');
const path = require('path');

const serverPath = path.join(process.env.HOME, 'QuantaOS', 'server.js');
let src = fs.readFileSync(serverPath, 'utf8');

// Check if already patched
if (src.includes('fdroid-index')) {
  console.log('✅ Already patched!');
  process.exit(0);
}

// The F-Droid proxy routes to inject
const proxy = `
// ==================== F-DROID PROXY ====================
// Fetches F-Droid server-side — no CORS issues in the browser

const https_mod = require('https');

function proxyFetch(url, res) {
    console.log('[F-Droid] Fetching:', url);
    const req = https_mod.get(url, {
        headers: { 'User-Agent': 'QuantaOS/1.0', 'Accept': 'application/json' },
        timeout: 90000
    }, (r) => {
        let data = [];
        r.on('data', chunk => data.push(chunk));
        r.on('end', () => {
            const buf = Buffer.concat(data);
            console.log('[F-Droid] Got', buf.length, 'bytes');
            res.setHeader('Content-Type', 'application/json');
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Content-Length', buf.length);
            res.status(200).end(buf);
        });
    });
    req.on('error', (e) => {
        console.error('[F-Droid] Error:', e.message);
        res.status(500).json({ error: e.message, apps: [], packages: {} });
    });
    req.on('timeout', () => {
        req.destroy();
        res.status(504).json({ error: 'Timeout fetching F-Droid', apps: [], packages: {} });
    });
}

// Full index (all ~4000+ apps at once)
app.get('/api/fdroid-index', (req, res) => {
    proxyFetch('https://f-droid.org/repo/index-v1.json', res);
});

// Paginated API (fallback)
app.get('/api/fdroid', (req, res) => {
    const limit  = req.query.limit  || '100';
    const offset = req.query.offset || '0';
    proxyFetch(\`https://f-droid.org/api/v1/packages/?limit=\${limit}&offset=\${offset}\`, res);
});

`;

// Inject just before the 404 handler
src = src.replace(
  '// 404 handler',
  proxy + '// 404 handler'
);

fs.writeFileSync(serverPath, src);
console.log('✅ F-Droid proxy added to server.js!');
console.log('   Restart server: cd ~/QuantaOS && node server.js');
