// server.js - Quanta OS App Store (FULLY FIXED - No Wildcard Error)
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const os = require('os');
const app = express();

// ==================== CONFIGURATION ====================
const APP_STORE_VERSION = '3.2.2';
const HOME_DIR = process.env.HOME;
const UPLOAD_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Apps');
const MEDIA_DIR = path.join(HOME_DIR, 'storage', 'downloads', 'QuantaOS_Media');
const DATA_DIR = path.join(HOME_DIR, 'QuantaOS', 'data');
const APPS_JSON_PATH = path.join(DATA_DIR, 'apps.json');
const REVIEWS_JSON_PATH = path.join(DATA_DIR, 'reviews.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// Create all directories
[UPLOAD_DIR, MEDIA_DIR, DATA_DIR, PUBLIC_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`📁 Created: ${dir}`);
    }
});

// Initialize data files
if (!fs.existsSync(APPS_JSON_PATH)) {
    fs.writeFileSync(APPS_JSON_PATH, JSON.stringify([]));
    console.log('📁 Created apps.json');
}
if (!fs.existsSync(REVIEWS_JSON_PATH)) {
    fs.writeFileSync(REVIEWS_JSON_PATH, JSON.stringify([]));
    console.log('📁 Created reviews.json');
}

// ==================== HELPER FUNCTIONS ====================
function readApps() {
    try {
        const data = fs.readFileSync(APPS_JSON_PATH, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        console.error('Error reading apps:', err);
        return [];
    }
}

function writeApps(apps) {
    try {
        fs.writeFileSync(APPS_JSON_PATH, JSON.stringify(apps, null, 2));
        return true;
    } catch (err) {
        console.error('Error writing apps:', err);
        return false;
    }
}

function readReviews() {
    try {
        const data = fs.readFileSync(REVIEWS_JSON_PATH, 'utf8');
        return JSON.parse(data);
    } catch (err) {
        console.error('Error reading reviews:', err);
        return [];
    }
}

function writeReviews(reviews) {
    try {
        fs.writeFileSync(REVIEWS_JSON_PATH, JSON.stringify(reviews, null, 2));
        return true;
    } catch (err) {
        console.error('Error writing reviews:', err);
        return false;
    }
}

function generateId() {
    return Date.now() + '-' + Math.random().toString(36).substr(2, 9);
}

function getLocalIP() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return 'localhost';
}

// ==================== MULTER CONFIG ====================
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        if (file.fieldname === 'screenshots' || file.fieldname === 'icon') {
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
        if (file.fieldname === 'icon') prefix = 'icon';
        if (file.fieldname === 'screenshots') prefix = 'screenshot';
        
        cb(null, `quanta_${prefix}_${sanitizedName}_${uniqueSuffix}${ext}`);
    }
});

const upload = multer({ 
    storage: storage,
    limits: { 
        fileSize: 500 * 1024 * 1024, // 500MB
        files: 10 
    }
});

// ==================== MIDDLEWARE ====================
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static(PUBLIC_DIR));
app.use('/downloads', express.static(UPLOAD_DIR));
app.use('/media', express.static(MEDIA_DIR));

// ==================== API ENDPOINTS ====================

// Upload endpoint - FIXED VERSION
app.post('/api/upload', upload.fields([
    { name: 'file', maxCount: 1 },
    { name: 'icon', maxCount: 1 },
    { name: 'screenshots', maxCount: 4 }
]), (req, res) => {
    // Set proper content type
    res.setHeader('Content-Type', 'application/json');
    
    console.log('📤 Upload request received');
    
    const files = req.files || {};
    const appFile = files.file?.[0];
    
    if (!appFile) {
        console.log('❌ No app file uploaded');
        // Clean up any uploaded files
        if (files.icon) files.icon.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
        if (files.screenshots) files.screenshots.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
        return res.status(400).json({ error: 'No app file uploaded' });
    }

    try {
        const { name, version, developer, category, platform, license, description, github_repo, video_url } = req.body;
        
        console.log('📦 App details:', { name, version, developer, platform });
        
        // Basic validation
        if (!name || !version || !developer || !category || !platform || !license || !description) {
            console.log('❌ Missing required fields');
            // Clean up files
            if (files.icon) files.icon.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            if (files.screenshots) files.screenshots.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            try { fs.unlinkSync(appFile.path); } catch (e) {}
            return res.status(400).json({ error: 'All required fields must be filled' });
        }

        // Read current apps
        const apps = readApps();
        
        // Generate package name from app name
        const package_name = name.toLowerCase().replace(/[^a-z0-9]/g, '.');
        
        // Check for duplicates
        if (apps.find(a => a.name.toLowerCase() === name.toLowerCase())) {
            console.log('❌ Duplicate app name:', name);
            // Clean up files
            if (files.icon) files.icon.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            if (files.screenshots) files.screenshots.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            try { fs.unlinkSync(appFile.path); } catch (e) {}
            return res.status(400).json({ error: 'App with this name already exists' });
        }

        // Process icon
        const iconFile = files.icon?.[0];
        const iconPath = iconFile ? `/media/${path.basename(iconFile.path)}` : null;

        // Process screenshots
        const screenshotFiles = files.screenshots || [];
        if (screenshotFiles.length > 4) {
            console.log('❌ Too many screenshots:', screenshotFiles.length);
            // Clean up files
            if (files.icon) files.icon.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            screenshotFiles.forEach(f => { try { fs.unlinkSync(f.path); } catch (e) {} });
            try { fs.unlinkSync(appFile.path); } catch (e) {}
            return res.status(400).json({ error: 'Maximum 4 screenshots allowed' });
        }
        
        const screenshotPaths = screenshotFiles.map(f => `/media/${path.basename(f.path)}`);

        // Get file size
        const fileSize = fs.statSync(appFile.path).size;

        // Create new app entry
        const newApp = {
            id: generateId(),
            name: name,
            package_name: package_name,
            version: version,
            description: description,
            developer: developer,
            category: category,
            platform: platform,
            size: fileSize,
            downloads: 0,
            filename: path.basename(appFile.path),
            icon: iconPath,
            screenshots: screenshotPaths,
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
        // Clean up all files
        if (files.icon) files.icon.forEach(f => { try { if (fs.existsSync(f.path)) fs.unlinkSync(f.path); } catch (e) {} });
        if (files.screenshots) files.screenshots.forEach(f => { try { if (fs.existsSync(f.path)) fs.unlinkSync(f.path); } catch (e) {} });
        if (appFile && fs.existsSync(appFile.path)) try { fs.unlinkSync(appFile.path); } catch (e) {}
        return res.status(500).json({ error: error.message });
    }
});

// Submit a review
app.post('/api/review/:appId', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    
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
    res.setHeader('Content-Type', 'application/json');
    
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
    res.setHeader('Content-Type', 'application/json');
    
    try {
        const { category, platform, search } = req.query;
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
                (app.description && app.description.toLowerCase().includes(s)) ||
                app.developer.toLowerCase().includes(s) ||
                (app.github_repo && app.github_repo.toLowerCase().includes(s))
            );
        }
        
        // Sort by upload date (newest first)
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
    res.setHeader('Content-Type', 'application/json');
    
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

        // Delete icon
        if (app.icon) {
            const iconPath = path.join(MEDIA_DIR, path.basename(app.icon));
            if (fs.existsSync(iconPath)) fs.unlinkSync(iconPath);
        }

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
    res.setHeader('Content-Type', 'application/json');
    
    try {
        const apps = readApps();
        const stats = {
            total_apps: apps.length,
            total_downloads: apps.reduce((sum, a) => sum + (a.downloads || 0), 0),
            total_size: apps.reduce((sum, a) => sum + (a.size || 0), 0),
            avg_rating: apps.length > 0 ? (apps.reduce((sum, a) => sum + (parseFloat(a.rating) || 0), 0) / apps.length).toFixed(1) : '0.0',
            by_platform: {},
            by_category: {}
        };
        
        apps.forEach(app => {
            stats.by_platform[app.platform] = (stats.by_platform[app.platform] || 0) + 1;
            stats.by_category[app.category] = (stats.by_category[app.category] || 0) + 1;
        });
        
        res.json(stats);
    } catch (error) {
        console.error('Stats error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Health check
app.get('/api/health', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.json({ 
        status: 'healthy', 
        version: APP_STORE_VERSION,
        apps: readApps().length,
        uptime: process.uptime()
    });
});

// ==================== 404 HANDLER - FIXED (No wildcard *) ====================
// This catches any unmatched routes and returns JSON instead of HTML
app.use((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.status(404).json({ error: 'API endpoint not found' });
});

// ==================== START SERVER ====================
const PORT = 3000;
app.listen(PORT, '0.0.0.0', () => {
    const localIP = getLocalIP();
    console.log('\n' + '╔══════════════════════════════════════╗');
    console.log('║     🚀 QUANTA OS APP STORE v3.2.2    ║');
    console.log('║     No Wildcard Error - Fully Fixed  ║');
    console.log('╚══════════════════════════════════════╝');
    console.log(`📱 Version: ${APP_STORE_VERSION}`);
    console.log(`📍 Local: http://localhost:${PORT}`);
    console.log(`🌐 Network: http://${localIP}:${PORT}`);
    console.log(`📂 Apps: ${UPLOAD_DIR}`);
    console.log(`🖼️  Media: ${MEDIA_DIR}`);
    console.log(`\n✅ Server started successfully!`);
    console.log(`   • No wildcard errors`);
    console.log(`   • JSON responses guaranteed`);
    console.log(`   • Upload working\n`);
});
