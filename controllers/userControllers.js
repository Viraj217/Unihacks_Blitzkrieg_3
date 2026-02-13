import pool from '../database/pool.js';

async function createProfile(req, res) {
    const user_data = req.body;
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
        res.send(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') {
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
    try {
        const user_id = req.params.id;
        const query = `
      SELECT id, email, username, display_name, avatar_url, bio, phone_number, created_at
      FROM profiles
      WHERE id = $1
    `;
        const result = await pool.query(query, [user_id]);
        res.send(result.rows[0]);
    }
    catch (error) {
        throw error;
    }
}

async function updateProfile(req, res) {
    const user_id = req.params.id;
    const updates = req.body;

    const query = `
      UPDATE profiles
      SET email = $1, username = $2, display_name = $3, bio = $4, phone_number = $5, avatar_url = $6
      WHERE id = $7
      RETURNING id, email, username, display_name, avatar_url, bio, phone_number, created_at
    `;

    const values = [
        updates.email || null,
        updates.username || null,
        updates.display_name || null,
        updates.bio || null,
        updates.phone_number || null,
        updates.avatar_url || null,
        user_id
    ];

    try {
        const result = await pool.query(query, values);
        res.send(result.rows[0]);
    } catch (error) {
        throw error;
    }
}

async function deleteProfile(req, res) {
    const user_id = req.params.id;
    const query = `
      DELETE FROM profiles
      WHERE id = $1
    `;
    try {
        await pool.query(query, [user_id]);
        res.send({ message: 'Profile deleted successfully' });
    } catch (error) {
        throw error;
    }
}
export { createProfile, getProfileByid, updateProfile, deleteProfile }