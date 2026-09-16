require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('node:path');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const { SecretClient } = require('@azure/keyvault-secrets');
const { DefaultAzureCredential } = require('@azure/identity');
const Redis = require('ioredis');

const prisma = new PrismaClient();
const app = express();
app.disable('x-powered-by');
const port = process.env.PORT || 3000;

// Only the origins we actually serve. An unrestricted cors() lets any site
// on the internet call this API with the user's credentials.
const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:5173').split(',');
app.use(cors({ origin: allowedOrigins }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'dist')));

let superSecret;

// --- REDIS (Distributed Cache) ---
const redis = new Redis({
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: Number.parseInt(process.env.REDIS_PORT || '6379', 10),
});

redis.on('connect', () => console.log('🟢 Connected to Redis Distributed Cache'));
redis.on('error', (err) => console.error('🔴 Redis Client Error', err));

// --- AUTH ROUTES ---
app.post('/api/auth/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        const hashedPassword = await bcrypt.hash(password, 10);
        await prisma.users.create({
            data: { username, password_hash: hashedPassword }
        });
        res.status(201).json({ success: true, message: 'User registered' });
    } catch (error) {
        console.error('Registration failed:', error);
        res.status(500).json({ success: false, error: 'Registration failed' });
    }
});

app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        const user = await prisma.users.findUnique({ where: { username } });
        if (!user) return res.status(401).json({ error: 'Invalid credentials' });

        const match = await bcrypt.compare(password, user.password_hash);
        if (!match) return res.status(401).json({ error: 'Invalid credentials' });

        const token = jwt.sign({ id: user.id, username: user.username }, process.env.JWT_SECRET, { expiresIn: '1h' });
        res.json({ success: true, token });
    } catch (error) {
        console.error('Login failed:', error);
        res.status(500).json({ success: false, error: 'Login failed' });
    }
});

// --- AUTH MIDDLEWARE ---
const verifyToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(403).json({ error: 'No token provided' });

    const token = authHeader.split(' ')[1];
    jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
        if (err) return res.status(401).json({ error: 'Unauthorized' });
        req.userId = decoded.id;
        next();
    });
};

// --- PRODUCTS (Redis Cache-Aside) ---
app.get('/api/products', async (req, res) => {
    const CACHE_KEY = 'products:all';
    try {
        const cachedData = await redis.get(CACHE_KEY);
        if (cachedData) {
            console.log("⚡ Redis Cache Hit");
            return res.json({ success: true, cached: true, data: JSON.parse(cachedData) });
        }

        console.log("🐢 Redis Cache Miss. Querying DB...");
        const products = await prisma.products.findMany({ take: 50 });

        await redis.set(CACHE_KEY, JSON.stringify(products), 'EX', 60);

        res.json({ success: true, cached: false, data: products });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Database error' });
    }
});

app.get('/api/products-with-categories', async (req, res) => {
    try {
        const products = await prisma.products.findMany({
            take: 50,
            include: { categories: true }
        });
        res.json({ success: true, data: products });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Database error' });
    }
});

app.get('/api/products/:id', async (req, res) => {
    try {
        const product = await prisma.products.findUnique({
            where: { ProductID: Number.parseInt(req.params.id, 10) }
        });
        if (!product) return res.status(404).json({ success: false, error: 'Product not found' });
        res.json({ success: true, data: product });
    } catch (error) {
        console.error('Lookup failed:', error);
        res.status(500).json({ success: false, error: 'Server Error' });
    }
});

app.post('/api/products', verifyToken, async (req, res) => {
    try {
        const { ProductName, SupplierID, CategoryID, Unit, Price } = req.body;
        if (!ProductName || !Price) return res.status(400).json({ error: 'Missing fields' });
        const newProduct = await prisma.products.create({
            data: {
                ProductName,
                SupplierID: SupplierID || 1,
                CategoryID: CategoryID || 1,
                Unit: Unit || '1 box',
                Price: Number.parseFloat(Price)
            }
        });

        await redis.del('products:all');

        res.status(201).json({ success: true, insertedId: newProduct.ProductID });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Insert failed' });
    }
});

app.put('/api/products/:id', verifyToken, async (req, res) => {
    try {
        const { ProductName, Price } = req.body;
        await prisma.products.update({
            where: { ProductID: Number.parseInt(req.params.id, 10) },
            data: { ProductName, Price: Number.parseFloat(Price) }
        });

        await redis.del('products:all');

        res.json({ success: true, message: 'Product updated' });
    } catch (error) {
        if (error.code === 'P2025') return res.status(404).json({ success: false, error: 'Product not found' });
        console.error('Product update failed:', error);
        res.status(500).json({ success: false, error: 'Update failed' });
    }
});

app.delete('/api/products/:id', verifyToken, async (req, res) => {
    try {
        await prisma.products.delete({
            where: { ProductID: Number.parseInt(req.params.id, 10) }
        });

        await redis.del('products:all');

        res.json({ success: true, message: 'Product deleted' });
    } catch (error) {
        if (error.code === 'P2025') return res.status(404).json({ success: false, error: 'Product not found' });
        console.error('Product delete failed:', error);
        res.status(500).json({ success: false, error: 'Delete failed' });
    }
});

// --- CATEGORIES ---
app.get('/api/categories', async (req, res) => {
    try {
        const categories = await prisma.categories.findMany();
        res.json({ success: true, data: categories });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Database error' });
    }
});

app.get('/api/categories/:id', async (req, res) => {
    try {
        const category = await prisma.categories.findUnique({
            where: { CategoryID: Number.parseInt(req.params.id, 10) }
        });
        if (!category) return res.status(404).json({ success: false, error: 'Category not found' });
        res.json({ success: true, data: category });
    } catch (error) {
        console.error('Lookup failed:', error);
        res.status(500).json({ success: false, error: 'Server Error' });
    }
});

app.post('/api/categories', verifyToken, async (req, res) => {
    try {
        const { CategoryName, Description } = req.body;
        if (!CategoryName) return res.status(400).json({ success: false, error: 'CategoryName is required' });
        const newCategory = await prisma.categories.create({
            data: { CategoryName, Description: Description || '' }
        });
        res.status(201).json({ success: true, insertedId: newCategory.CategoryID });
    } catch (error) {
        console.error('Category insert failed:', error);
        res.status(500).json({ success: false, error: 'Insert failed' });
    }
});

app.put('/api/categories/:id', verifyToken, async (req, res) => {
    try {
        const { CategoryName, Description } = req.body;
        await prisma.categories.update({
            where: { CategoryID: Number.parseInt(req.params.id, 10) },
            data: { CategoryName, Description }
        });
        res.json({ success: true, message: 'Category updated' });
    } catch (error) {
        if (error.code === 'P2025') return res.status(404).json({ success: false, error: 'Category not found' });
        console.error('Category update failed:', error);
        res.status(500).json({ success: false, error: 'Update failed' });
    }
});

app.delete('/api/categories/:id', verifyToken, async (req, res) => {
    try {
        await prisma.categories.delete({
            where: { CategoryID: Number.parseInt(req.params.id, 10) }
        });
        res.json({ success: true, message: 'Category deleted' });
    } catch (error) {
        if (error.code === 'P2025') return res.status(404).json({ success: false, error: 'Category not found' });
        console.error('Category delete failed:', error);
        res.status(500).json({ success: false, error: 'Delete failed' });
    }
});

// --- BOOTSTRAP: fetch secrets from Azure Key Vault, THEN start server ---
async function bootstrapServer() {
    try {
        console.log("🔒 Connecting to Azure Key Vault...");
        const vaultUrl = process.env.KEY_VAULT_URL;
        console.log({ vaultUrl });

        const credential = new DefaultAzureCredential();
        const client = new SecretClient(vaultUrl, credential);

        const superSecretObj = await client.getSecret('SUPERSECRET');
        superSecret = superSecretObj.value;

        console.log("✅ Secrets fetched successfully.");

        app.listen(port, () => {
            console.log(`🚀 Secure API running on port ${port}`);
        });
    } catch (error) {
        console.error("❌ CRITICAL: Failed to bootstrap secure server:", error);
        process.exit(1);
    }
}

bootstrapServer();
