import pool from './pool.js';

const createTable = async () => {
    try {
        const query = `
            CREATE TABLE IF NOT EXISTS user_posts (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
                image_url TEXT NOT NULL,
                caption TEXT,
                created_at TIMESTAMP DEFAULT NOW(),
                likes_count INTEGER DEFAULT 0
            );

            CREATE INDEX IF NOT EXISTS idx_user_posts_created_at ON user_posts(created_at DESC);
        `;

        await pool.query(query);
        console.log('User posts table created successfully');
    } catch (err) {
        console.error('Error creating user posts table:', err);
    } finally {
        pool.end();
    }
};

createTable();
