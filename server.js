// server.js - Quanta OS App Store with GitHub Support
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');
const { exec } = require('child_process');
const app = express();

// ==================== CONFIGURATION ====================
const APP_STORE_VERSION = '3.1.0';
const HOME_DIR = process.env.HOME;
const UPLOAD_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Apps');
const MEDIA_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Media');
const DATA_DIR = path.join(HOME_DIR, 'QuantaOS', 'data');
const APPS_JSON_PATH = path.join(DATA_DIR, 'apps.json');
const REVIEWS_JSON_PATH = path.join(DATA_DIR, 'reviews.json');
const BANNED_HASHES_PATH = path.join(DATA_DIR, 'banned_hashes.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// Create all directories
[UPLOAD_DIR, MEDIA_DIR, DATA_DIR, PUBLIC_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`📁 Created: ${dir}`);
    }
});

// Initialize data files
if (!fs.existsSync(APPS_JSON_PATH)) fs.writeFileSync(APPS_JSON_PATH, JSON.stringify([]));
if (!fs.existsSync(REVIEWS_JSON_PATH)) fs.writeFileSync(REVIEWS_JSON_PATH, JSON.stringify([]));
if (!fs.existsSync(BANNED_HASHES_PATH)) {
    fs.writeFileSync(BANNED_HASHES_PATH, JSON.stringify([]));
}

// ==================== HELPER FUNCTIONS ====================
function readApps() {
    try { return JSON.parse(fs.readFileSync(APPS_JSON_PATH)); } 
    catch { return []; }
}

function writeApps(apps) {
    try { fs.writeFileSync(APPS_JSON_PATH, JSON.stringify(apps, null, 2)); return true; } 
    catch { return false; }
}

function readReviews() {
    try { return JSON.parse(fs.readFileSync(REVIEWS_JSON_PATH)); } 
    catch { return []; }
}

function writeReviews(reviews) {
    try { fs.writeFileSync(REVIEWS_JSON_PATH, JSON.stringify(reviews, null, 2)); return true; } 
    catch { return false; }
}

function readBannedHashes() {
    try { return JSON.parse(fs.readFileSync(BANNED_HASHES_PATH)); } 
    catch { return []; }
}

function generateId() {
    return Date.now() + '-' + Math.random().toString(36).substr(2, 9);
}

function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) return iface.address;
        }
    }
    return 'localhost';
}

// ==================== APP VERIFICATION SYSTEM ====================

// Calculate file hash
function calculateFileHash(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    return hashSum.digest('hex');
}

// Check for open source indicators in APK
async function checkOpenSource(filePath) {
    return new Promise((resolve) => {
        const commands = [
            `strings "${filePath}" | grep -i "license\\|gpl\\|mit\\|apache\\|bsd\\|lgpl\\|mpl" | head -5`,
            `strings "${filePath}" | grep -i "opensource\\|open-source\\|free software" | head -3`,
            `unzip -p "${filePath}" META-INF/MANIFEST.MF 2>/dev/null | grep -i "license" || echo ""`
        ];
        
        let openSourceIndicators = [];
        let executed = 0;
        
        commands.forEach(cmd => {
            exec(cmd, (error, stdout) => {
                if (stdout && stdout.trim()) {
                    openSourceIndicators.push(stdout.trim());
                }
                executed++;
                if (executed === commands.length) {
                    const score = Math.min(openSourceIndicators.length * 33, 100);
                    resolve({
                        isOpenSource: openSourceIndicators.length > 0,
                        confidence: score,
                        licenses: openSourceIndicators.join(', ').substring(0, 200)
                    });
                }
            });
        });
    });
}

// Quick virus/malware scan
async function scanForMalware(filePath) {
    return new Promise((resolve) => {
        const fileHash = calculateFileHash(filePath);
        const bannedHashes = readBannedHashes();
        const fileSize = fs.statSync(filePath).size;
        
        if (bannedHashes.includes(fileHash)) {
            return resolve({ 
                safe: false, 
                reason: 'Known malware hash detected',
                score: 0
            });
        }
        
        const commands = [
            `strings "${filePath}" | grep -i "malware\\|virus\\|trojan\\|keylogger\\|ransom" | head -3`,
            `strings "${filePath}" | grep -i "permission\\:android.permission.READ_SMS\\|android.permission.SEND_SMS" | head -3`,
            `strings "${filePath}" | grep -i "permission\\:android.permission.RECORD_AUDIO\\|android.permission.CAMERA" | head -5`
        ];
        
        let suspicious = [];
        let executed = 0;
        
        commands.forEach(cmd => {
            exec(cmd, (error, stdout) => {
                if (stdout && stdout.trim()) {
                    suspicious.push(stdout.trim());
                }
                executed++;
                if (executed === commands.length) {
                    let safetyScore = 100;
                    if (suspicious.length > 0) {
                        safetyScore -= suspicious.length * 15;
                    }
                    if (suspicious.some(s => s.includes('malware') || s.includes('virus'))) {
                        safetyScore -= 30;
                    }
                    if (suspicious.length > 3) safetyScore -= 20;
                    
                    resolve({
                        safe: safetyScore >= 70,
                        score: Math.max(safetyScore, 0),
                        warnings: suspicious.slice(0, 3),
                        hash: fileHash
                    });
                }
            });
        });
    });
}

// Extract app info from APK
async function extractAppInfo(filePath) {
    return new Promise((resolve) => {
        const commands = [
            `unzip -p "${filePath}" AndroidManifest.xml 2>/dev/null | strings | grep -o 'package="[^"]*"' | head -1`,
            `unzip -p "${filePath}" AndroidManifest.xml 2>/dev/null | strings | grep -o 'versionName="[^"]*"' | head -1`,
            `unzip -p "${filePath}" AndroidManifest.xml 2>/dev/null | strings | grep -o 'versionCode="[^"]*"' | head -1`
        ];
        
        let info = { package: 'unknown', version: 'unknown', versionCode: '0' };
        let executed = 0;
        
        commands.forEach((cmd, index) => {
            exec(cmd, (error, stdout) => {
                if (stdout) {
                    if (index === 0) {
                        const match = stdout.match(/package="([^"]*)"/);
                        if (match) info.package = match[1];
                    } else if (index === 1) {
                        const match = stdout.match(/versionName="([^"]*)"/);
                        if (match) info.version = match[1];
                    } else if (index === 2) {
                        const match = stdout.match(/versionCode="([^"]*)"/);
                        if (match) info.versionCode = match[1];
                    }
                }
                executed++;
                if (executed === commands.length) resolve(info);
            });
        });
    });
}

// ==================== MULTER CONFIG ====================
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        if (file.fieldname === 'screenshots') {
            cb(null, MEDIA_DIR);
        } else {
            cb(null, UPLOAD_DIR);
        }
    },
    filename: (req, file, cb) => {
        const sanitizedName = req.body.name?.replace(/[^a-z0-9]/gi, '_').toLowerCase() || 'app';
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        
        let prefix = 'app';
        if (file.fieldname === 'screenshots') prefix = 'screenshot';
        
        cb(null, `quanta_${prefix}_${sanitizedName}_${uniqueSuffix}${ext}`);
    }
});

const upload = multer({ 
    storage: storage,
    limits: { fileSize: 500 * 1024 * 1024, files: 10 }
});

// ==================== MIDDLEWARE ====================
app.use(express.json({ limit: '50mb' }));
app.use(express.static(PUBLIC_DIR));
app.use('/downloads', express.static(UPLOAD_DIR));
app.use('/media', express.static(MEDIA_DIR));

// ==================== API ENDPOINTS ====================

// Upload with automatic verification
app.post('/api/upload', upload.fields([
    { name: 'file', maxCount: 1 },
    { name: 'screenshots', maxCount: 4 }
]), async (req, res) => {
    const startTime = Date.now();
    const files = req.files || {};
    const appFile = files.file?.[0];
    
    if (!appFile) {
        // Clean up any uploaded files
        if (files.screenshots) {
            files.screenshots.forEach(f => fs.unlinkSync(f.path));
        }
        return res.status(400).json({ error: 'No app file uploaded' });
    }

    try {
        // Step 1: Quick malware scan
        const scanResult = await scanForMalware(appFile.path);
        
        if (!scanResult.safe) {
            // Clean up files
            if (files.screenshots) {
                files.screenshots.forEach(f => fs.unlinkSync(f.path));
            }
            fs.unlinkSync(appFile.path);
            return res.status(400).json({ 
                error: 'Security check failed',
                details: scanResult.reason || 'Potential malware detected'
            });
        }

        // Step 2: Check if open source
        const osResult = await checkOpenSource(appFile.path);
        
        if (!osResult.isOpenSource) {
            // Clean up files
            if (files.screenshots) {
                files.screenshots.forEach(f => fs.unlinkSync(f.path));
            }
            fs.unlinkSync(appFile.path);
            return res.status(400).json({ 
                error: 'Open source check failed',
                details: 'App must be open source (GPL, MIT, Apache, etc.)'
            });
        }

        // Step 3: Extract app info
        const appInfo = await extractAppInfo(appFile.path);

        // Step 4: Save app data
        const apps = readApps();
        
        // Check for duplicates
        if (apps.find(a => a.package_name === appInfo.package)) {
            // Clean up files
            if (files.screenshots) {
                files.screenshots.forEach(f => fs.unlinkSync(f.path));
            }
            fs.unlinkSync(appFile.path);
            return res.status(400).json({ error: 'App with this package already exists' });
        }

        // Process screenshots
        const screenshotFiles = files.screenshots || [];
        const screenshotPaths = screenshotFiles.map(f => `/media/${path.basename(f.path)}`);

        // Create new app entry with GitHub support
        const newApp = {
            id: generateId(),
            name: req.body.name,
            package_name: appInfo.package,
            version: req.body.version || appInfo.version,
            description: req.body.description || '',
            developer: req.body.developer || 'Unknown',
            category: req.body.category || 'Other',
            platform: req.body.platform || 'android',
            size: fs.statSync(appFile.path).size,
            downloads: 0,
            filename: path.basename(appFile.path),
            screenshots: screenshotPaths,
            github_repo: req.body.github_repo || null,  // GitHub repository (optional)
            video_url: req.body.video_url || null,
            upload_date: new Date().toISOString(),
            license: req.body.license || 'Open Source',
            
            // Verification results
            verified: {
                safe: true,
                safetyScore: scanResult.score,
                openSource: true,
                openSourceConfidence: osResult.confidence,
                licenses: osResult.licenses,
                scanHash: scanResult.hash,
                verifiedAt: new Date().toISOString()
            },
            
            // Stats
            rating: 0,
            reviewCount: 0,
            totalRatings: 0
        };

        apps.push(newApp);
        
        if (writeApps(apps)) {
            const processTime = Date.now() - startTime;
            res.json({ 
                success: true, 
                message: '✅ App verified and uploaded!',
                appId: newApp.id,
                verification: {
                    safe: true,
                    openSource: true,
                    timeMs: processTime
                }
            });
        } else {
            // Clean up files if save failed
            if (files.screenshots) {
                files.screenshots.forEach(f => fs.unlinkSync(f.path));
            }
            fs.unlinkSync(appFile.path);
            res.status(500).json({ error: 'Failed to save app data' });
        }

    } catch (error) {
        console.error('Upload error:', error);
        // Clean up all files
        if (files.screenshots) {
            files.screenshots.forEach(f => { if (fs.existsSync(f.path)) fs.unlinkSync(f.path); });
        }
        if (appFile && fs.existsSync(appFile.path)) fs.unlinkSync(appFile.path);
        res.status(500).json({ error: error.message });
    }
});

// Submit a review
app.post('/api/review/:appId', (req, res) => {
    try {
        const { rating, comment, userName } = req.body;
        const appId = req.params.appId;
        
        if (!rating || rating < 1 || rating > 5) {
            return res.status(400).json({ error: 'Rating must be 1-5' });
        }

        const apps = readApps();
        const appIndex = apps.findIndex(a => a.id === appId);
        
        if (appIndex === -1) {
            return res.status(404).json({ error: 'App not found' });
        }

        const reviews = readReviews();
        
        const newReview = {
            id: generateId(),
            appId: appId,
            rating: parseInt(rating),
            comment: comment || '',
            userName: userName || 'Anonymous',
            date: new Date().toISOString()
        };
        
        reviews.push(newReview);
        
        // Update app rating
        const appReviews = reviews.filter(r => r.appId === appId);
        const totalRating = appReviews.reduce((sum, r) => sum + r.rating, 0);
        apps[appIndex].rating = (totalRating / appReviews.length).toFixed(1);
        apps[appIndex].reviewCount = appReviews.length;
        
        if (writeReviews(reviews) && writeApps(apps)) {
            res.json({ 
                success: true, 
                message: 'Review added',
                newRating: apps[appIndex].rating
            });
        } else {
            res.status(500).json({ error: 'Failed to save review' });
        }
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get reviews for an app
app.get('/api/reviews/:appId', (req, res) => {
    try {
        const reviews = readReviews();
        const appReviews = reviews.filter(r => r.appId === req.params.appId)
            .sort((a, b) => new Date(b.date) - new Date(a.date));
        res.json(appReviews);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get all apps
app.get('/api/apps', (req, res) => {
    try {
        const { category, platform, search, sort } = req.query;
        let apps = readApps();
        
        // Apply filters
        if (category && category !== 'all') {
            apps = apps.filter(app => app.category === category);
        }
        if (platform && platform !== 'all') {
            apps = apps.filter(app => app.platform === platform);
        }
        if (search) {
            const s = search.toLowerCase();
            apps = apps.filter(app => 
                app.name.toLowerCase().includes(s) ||
                app.description?.toLowerCase().includes(s) ||
                app.developer.toLowerCase().includes(s) ||
                (app.github_repo && app.github_repo.toLowerCase().includes(s))
            );
        }
        
        // Sort
        if (sort === 'rating') {
            apps.sort((a, b) => (b.rating || 0) - (a.rating || 0));
        } else if (sort === 'downloads') {
            apps.sort((a, b) => (b.downloads || 0) - (a.downloads || 0));
        } else {
            apps.sort((a, b) => new Date(b.upload_date) - new Date(a.upload_date));
        }
        
        res.json(apps);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get single app
app.get('/api/apps/:id', (req, res) => {
    try {
        const apps = readApps();
        const app = apps.find(a => a.id === req.params.id);
        if (!app) return res.status(404).json({ error: 'App not found' });
        res.json(app);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Download with tracking
app.get('/api/download/:id', (req, res) => {
    try {
        const apps = readApps();
        const appIndex = apps.findIndex(a => a.id === req.params.id);
        if (appIndex === -1) return res.status(404).json({ error: 'App not found' });

        const app = apps[appIndex];
        const filePath = path.join(UPLOAD_DIR, app.filename);
        if (!fs.existsSync(filePath)) return res.status(404).json({ error: 'File not found' });

        app.downloads++;
        apps[appIndex] = app;
        writeApps(apps);

        const ext = path.extname(filePath).toLowerCase();
        const contentTypes = {
            '.apk': 'application/vnd.android.package-archive',
            '.ipa': 'application/octet-stream',
            '.exe': 'application/x-msdownload',
            '.msi': 'application/x-msi',
            '.dmg': 'application/x-apple-diskimage',
            '.pkg': 'application/x-newton-compatible-pkg',
            '.AppImage': 'application/x-iso9660-appimage',
            '.deb': 'application/vnd.debian.binary-package',
            '.rpm': 'application/x-rpm',
            '.zip': 'application/zip'
        };
        
        if (contentTypes[ext]) {
            res.setHeader('Content-Type', contentTypes[ext]);
        }

        res.download(filePath, `${app.name}-${app.version}${ext}`);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Delete app (protected)
app.delete('/api/apps/:id', (req, res) => {
    const adminKey = req.headers['admin-key'];
    if (adminKey !== 'QuantaOS2024') {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const apps = readApps();
        const appIndex = apps.findIndex(a => a.id === req.params.id);
        if (appIndex === -1) return res.status(404).json({ error: 'App not found' });

        const app = apps[appIndex];
        const filePath = path.join(UPLOAD_DIR, app.filename);
        if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

        // Delete screenshots
        if (app.screenshots) {
            app.screenshots.forEach(s => {
                const shotPath = path.join(MEDIA_DIR, path.basename(s));
                if (fs.existsSync(shotPath)) fs.unlinkSync(shotPath);
            });
        }

        apps.splice(appIndex, 1);
        writeApps(apps);

        // Delete reviews
        const reviews = readReviews();
        const filteredReviews = reviews.filter(r => r.appId !== req.params.id);
        writeReviews(filteredReviews);

        res.json({ success: true, message: 'App deleted' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get stats
app.get('/api/stats', (req, res) => {
    try {
        const apps = readApps();
        const stats = {
            total_apps: apps.length,
            total_downloads: apps.reduce((sum, a) => sum + (a.downloads || 0), 0),
            total_size: apps.reduce((sum, a) => sum + (a.size || 0), 0),
            avg_rating: (apps.reduce((sum, a) => sum + (parseFloat(a.rating) || 0), 0) / apps.length || 0).toFixed(1),
            by_platform: {},
            by_category: {}
        };
        
        apps.forEach(app => {
            stats.by_platform[app.platform] = (stats.by_platform[app.platform] || 0) + 1;
            stats.by_category[app.category] = (stats.by_category[app.category] || 0) + 1;
        });
        
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health check
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        version: APP_STORE_VERSION,
        apps: readApps().length,
        uptime: process.uptime()
    });
});

// ==================== START SERVER ====================
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    const localIP = getLocalIP();
    console.log('\n' + '╔══════════════════════════════════════╗');
    console.log('║     🚀 QUANTA OS APP STORE v3.1      ║');
    console.log('║     With GitHub Repository Support   ║');
    console.log('╚══════════════════════════════════════╝');
    console.log(`📱 Version: ${APP_STORE_VERSION}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`🌐 Network: http://${localIP}:${PORT}`);
    console.log(`📂 Apps: ${UPLOAD_DIR}`);
    console.log(`🖼️  Media: ${MEDIA_DIR}`);
    console.log(`\n✅ GitHub integration enabled!`);
    console.log(`   • Users can add GitHub repos during upload`);
    console.log(`   • GitHub badges appear on app cards\n`);
});
