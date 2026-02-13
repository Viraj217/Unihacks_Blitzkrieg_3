import pool from '../database/pool.js';

async function createProfile(req, res) {
    user_data = req.body;
    const query = `
      INSERT INTO profiles (email, username, display_name, password_hash , bio , phone_number , avatar_url)
      VALUES ($1, $2, $3, $4 , $5, $6, $7)
      RETURNING id, email, username, display_name, avatar_url, created_at
    `;

    const values = [
        user_data.email,
        user_data.username,
        user_data.display_name,
        user_data.password_hash,
        user_data.bio || '',
        user_data.phone_number || '',
        user_data.avatar_url || ''
    ];

    try {
        const result = await pool.query(query, values);
        return result.rows[0];
    } catch (error) {
        if (error.code === '23505') { // Unique violation
            if (error.constraint === 'profiles_email_key') {
                throw new Error('Email already exists');
            }
            if (error.constraint === 'profiles_username_key') {
                throw new Error('Username already exists');
            }
        }
        throw error;
    }
}

async function getProfileByid(req, res) {
    user_id = req.params.id;
    const query = `
      SELECT id, email, username, display_name, avatar_url, bio, phone_number, created_at
      FROM profiles
      WHERE id = $1
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows[0];
}