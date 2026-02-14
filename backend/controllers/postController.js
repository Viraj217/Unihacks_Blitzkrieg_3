import pool from '../database/pool.js';
import multer from 'multer';
import path from 'path';

// Multer storage configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/')
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9)
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname))
    }
})

// Configure multer
export const upload = multer({
    storage: storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only images are allowed'));
        }
    }
});

export const createPost = async (req, res) => {
    const authId = req.user.id;
    const { caption } = req.body;
    let imageUrl = '';

    if (!req.file) {
        return res.status(400).json({ error: 'Image is required' });
    }

    imageUrl = `/uploads/${req.file.filename}`;

    // Get host URL to form complete URL if needed, but relative is better for now.
    // For mobile app, we need full URL.
    const fullImageUrl = `${req.protocol}://${req.get('host')}${imageUrl}`;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Get profile ID from auth ID
        const profileResult = await client.query(
            'SELECT id FROM profiles WHERE auth_id = $1',
            [authId]
        );

        if (profileResult.rows.length === 0) {
            throw new Error('User profile not found');
        }

        const profileId = profileResult.rows[0].id;

        const query = `
            INSERT INTO user_posts (user_id, image_url, caption)
            VALUES ($1, $2, $3)
            RETURNING *
        `;
        const result = await client.query(query, [profileId, fullImageUrl, caption]);

        await client.query('COMMIT');

        // Fetch user details to return
        const userQuery = `
            SELECT username, display_name, avatar_url 
            FROM profiles WHERE id = $1
        `;
        const userResult = await client.query(userQuery, [profileId]);

        res.status(201).json({
            ...result.rows[0],
            username: userResult.rows[0].username,
            avatar_url: userResult.rows[0].avatar_url
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error(err);
        res.status(500).json({ error: err.message || 'Failed to create post' });
    } finally {
        client.release();
    }
};

export const getPosts = async (req, res) => {
    try {
        const query = `
            SELECT p.*, u.username, u.display_name, u.avatar_url
            FROM user_posts p
            JOIN profiles u ON p.user_id = u.id
            ORDER BY p.created_at DESC
        `;
        const result = await pool.query(query);
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: 'Failed to fetch posts' });
    }
};
