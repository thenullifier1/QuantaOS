const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');
const { saveAppToSupabase } = require('./supabase-storage');

const app = express();

// ==================== CONFIGURATION ====================
const APP_STORE_VERSION = '3.2.4';
const HOME_DIR = process.env.HOME;
const UPLOAD_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Apps');
const MEDIA_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Media');
const DATA_DIR = path.join(HOME_DIR, 'QuantaOS', 'data');
const APPS_JSON_PATH = path.join(DATA_DIR, 'apps.json');
const REVIEWS_JSON_PATH = path.join(DATA_DIR, 'reviews.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// Ensure directories exist
[DATA_DIR, UPLOAD_DIR, MEDIA_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// Initialize apps.json if it doesn't exist
if (!fs.existsSync(APPS_JSON_PATH)) {
    fs.writeFileSync(APPS_JSON_PATH, '[]');
}

// Initialize reviews.json if it doesn't exist
if (!fs.existsSync(REVIEWS_JSON_PATH)) {
    fs.writeFileSync(REVIEWS_JSON_PATH, '{}');
}

// Helper functions
function readApps() {
    try {
        return JSON.parse(fs.readFileSync(APPS_JSON_PATH, 'utf8'));
    } catch (e) {
        return [];
    }
}

function writeApps(apps) {
    try {
        fs.writeFileSync(APPS_JSON_PATH, JSON.stringify(apps, null, 2));
        return true;
    } catch (e) {
        console.error('Error writing apps:', e);
        return false;
    }
}

function readReviews() {
    try {
        return JSON.parse(fs.readFileSync(REVIEWS_JSON_PATH, 'utf8'));
    } catch (e) {
        return {};
    }
}

function writeReviews(reviews) {
    try {
        fs.writeFileSync(REVIEWS_JSON_PATH, JSON.stringify(reviews, null, 2));
        return true;
    } catch (e) {
        console.error('Error writing reviews:', e);
        return false;
    }
}

function generateAppId(name, developer) {
    const base = `${name}-${developer}`.toLowerCase().replace(/[^a-z0-9]+/g, '-');
    const timestamp = Date.now().toString(36);
    return `${base}-${timestamp}`;
}

// ==================== UPLOAD CONFIGURATION ====================
// Use memory storage for Supabase
const memoryStorage = multer.memoryStorage();

const upload = multer({
    storage: memoryStorage,
    limits: {
        fileSize: 500 * 1024 * 1024, // 500MB
        files: 10,
        fieldSize: 50 * 1024 * 1024,
        fields: 20
    }
});

// ==================== MIDDLEWARE ====================
app.use(express.json({ limit: '500mb' }));
app.use(express.urlencoded({ extended: true, limit: '500mb' }));

// Add keep-alive and timeout headers
app.use((req, res, next) => {
    if (req.path === '/api/upload') {
        req.setTimeout(300000);
        res.setTimeout(300000);
    } else {
        req.setTimeout(120000);
        res.setTimeout(120000);
    }

    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Keep-Alive', 'timeout=300');
    next();
});

app.use(express.static(PUBLIC_DIR));

// ==================== API ENDPOINTS ====================

// Test endpoint
app.get('/api/test', (req, res) => {
    res.json({ status: 'ok', message: 'Server is running' });
});

// Upload endpoint with Supabase storage
app.post('/api/upload', (req, res) => {
    req.setTimeout(300000);
    res.setTimeout(300000);

    req.on('error', (err) => {
        console.error('Request error:', err);
    });

    res.on('error', (err) => {
        console.error('Response error:', err);
    });

    res.setHeader('Content-Type', 'application/json');
    console.log('📤 Upload request received');

    const uploadMiddleware = upload.fields([
        { name: 'file', maxCount: 1 },
        { name: 'icon', maxCount: 1 },
        { name: 'screenshots', maxCount: 4 }
    ]);

    uploadMiddleware(req, res, async (err) => {
        if (err) {
            console.error('Multer error:', err);

            if (err.message === 'Request aborted') {
                console.log('❌ Upload aborted by client');
                return;
            }

            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(400).json({ error: 'File too large. Max size is 500MB' });
            }
            if (err.code === 'LIMIT_UNEXPECTED_FILE') {
                return res.status(400).json({ error: 'Too many files uploaded' });
            }
            return res.status(400).json({ error: err.message });
        }

        const files = req.files || {};
        const appFile = files.file?.[0];

        if (!appFile) {
            console.log('❌ No app file uploaded');
            return res.status(400).json({ error: 'No app file uploaded' });
        }

        try {
            const { name, version, developer, category, platform, license, description, github_repo, video_url } = req.body;

            console.log('📦 App details:', { name, version, developer, platform });

            if (!name || !version || !developer || !category || !platform || !license || !description) {
                console.log('❌ Missing required fields');
                return res.status(400).json({ error: 'All required fields must be filled' });
            }

            // Upload to Supabase
            const appFileUrl = await saveAppToSupabase(appFile, { type: 'app' });

            let iconUrl = null;
            if (files.icon?.[0]) {
                iconUrl = await saveAppToSupabase(files.icon[0], { type: 'icon' });
            }

            const screenshotUrls = [];
            if (files.screenshots) {
                for (const screenshot of files.screenshots) {
                    const url = await saveAppToSupabase(screenshot, { type: 'screenshot' });
                    screenshotUrls.push(url);
                }
            }

            const apps = readApps();
            const id = generateAppId(name, developer);

            const newApp = {
                id: id,
                name: name,
                version: version,
                developer: developer,
                category: category,
                platform: platform,
                description: description,
                filename: appFileUrl,
                icon: iconUrl,
                screenshots: screenshotUrls,
                github_repo: github_repo || null,
                video_url: video_url || null,
                upload_date: new Date().toISOString(),
                license: license,
                verified: true,
                rating: 0,
                reviewCount: 0
            };

            apps.push(newApp);

            if (writeApps(apps)) {
                console.log('✅ App uploaded successfully:', name);
                return res.status(200).json({
                    success: true,
                    message: '✅ App uploaded successfully!',
                    appId: newApp.id
                });
            } else {
                throw new Error('Failed to save app data');
            }

        } catch (error) {
            console.error('❌ Upload error:', error.message);
            return res.status(500).json({ error: error.message });
        }
    });
});

// Submit a review
app.post('/api/review/:appId', (req, res) => {
    res.setHeader('Content-Type', 'application/json');

    try {
        const { rating, comment, user } = req.body;
        const appId = req.params.appId;

        if (!rating || !comment) {
            return res.status(400).json({ error: 'Rating and comment are required' });
        }

        const reviews = readReviews();
        if (!reviews[appId]) {
            reviews[appId] = [];
        }

        const newReview = {
            id: Date.now().toString(36),
            user: user || 'Anonymous',
            rating: parseInt(rating),
            comment: comment,
            date: new Date().toISOString()
        };

        reviews[appId].push(newReview);

        // Update app rating
        const apps = readApps();
        const appIndex = apps.findIndex(a => a.id === appId);
        if (appIndex !== -1) {
            const appReviews = reviews[appId];
            const totalRating = appReviews.reduce((sum, r) => sum + r.rating, 0);
            apps[appIndex].rating = totalRating / appReviews.length;
            apps[appIndex].reviewCount = appReviews.length;
            writeApps(apps);
        }

        if (writeReviews(reviews)) {
            res.json({ success: true, review: newReview });
        } else {
            throw new Error('Failed to save review');
        }
    } catch (error) {
        console.error('Review error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get reviews for an app
app.get('/api/reviews/:appId', (req, res) => {
    res.setHeader('Content-Type', 'application/json');

    try {
        const reviews = readReviews();
        const appReviews = reviews[req.params.appId] || [];
        res.json(appReviews);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get all apps
app.get('/api/apps', (req, res) => {
    res.setHeader('Content-Type', 'application/json');

    try {
        let apps = readApps();
        const { search, category, platform } = req.query;

        if (category) {
            apps = apps.filter(app => app.category === category);
        }
        if (platform) {
            apps = apps.filter(app => app.platform === platform);
        }
        if (search) {
            const s = search.toLowerCase();
            apps = apps.filter(app => 
                app.name.toLowerCase().includes(s) ||
                app.description.toLowerCase().includes(s) ||
                app.developer.toLowerCase().includes(s) ||
                (app.github_repo && app.github_repo.toLowerCase().includes(s))
            );
        }

        apps.sort((a, b) => new Date(b.upload_date) - new Date(a.upload_date));
        res.json(apps);
    } catch (error) {
        console.error('Error getting apps:', error);
        res.status(500).json({ error: error.message });
    }
});

// Get single app
app.get('/api/apps/:id', (req, res) => {
    res.setHeader('Content-Type', 'application/json');

    try {
        const apps = readApps();
        const app = apps.find(a => a.id === req.params.id);
        if (!app) return res.status(404).json({ error: 'App not found' });
        res.json(app);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Download app
app.get('/api/download/:appId', (req, res) => {
    try {
        const apps = readApps();
        const app = apps.find(a => a.id === req.params.appId);
        
        if (!app) {
            return res.status(404).json({ error: 'App not found' });
        }

        // Redirect to Supabase URL or serve file
        if (app.filename.startsWith('http')) {
            res.redirect(app.filename);
        } else {
            const filePath = path.join(UPLOAD_DIR, path.basename(app.filename));
            if (fs.existsSync(filePath)) {
                res.download(filePath);
            } else {
                res.status(404).json({ error: 'File not found' });
            }
        }
    } catch (error) {
        console.error('Download error:', error);
        res.status(500).json({ error: error.message });
    }
});

// ==================== START SERVER ====================
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

app.listen(PORT, HOST, () => {
    console.log('\n╔══════════════════════════════════════╗');
    console.log('║     🚀 QUANTA OS APP STORE v3.2.4    ║');
    console.log('║     Ultimate Connection Fix          ║');
    console.log('╚══════════════════════════════════════╝');
    console.log(`📱 Version: ${APP_STORE_VERSION}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    
    // Get local IP
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            if (net.family === 'IPv4' && !net.internal) {
                console.log(`🌐 Network: http://${net.address}:${PORT}`);
            }
        }
    }
    
    console.log(`📂 Apps: ${UPLOAD_DIR}`);
    console.log(`🖼️  Media: ${MEDIA_DIR}`);
    console.log('\n✅ Server started successfully with Supabase storage!');
    console.log('   • Connection timeouts: 5 minutes');
    console.log('   • Keep-alive enabled');
    console.log('   • Upload errors: FIXED\n');
});

module.exports = app;
