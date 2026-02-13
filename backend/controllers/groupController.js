import pool from "../config/db.js";

async function createGroup(req, res) {
    const { name, description, avatar_url } = req.body;
    const created_by = req.user.id;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        const inviteCodeResult = await client.query('SELECT generate_invite_code() as code');
        const invite_code = inviteCodeResult.rows[0].code;

        const groupQuery = `
            INSERT INTO groups (name, description, avatar_url, invite_code, created_by)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *
        `;

        const groupResult = await client.query(groupQuery, [
            name,
            description || null,
            avatar_url || null,
            invite_code,
            created_by
        ]);

        const group = groupResult.rows[0];

        // Add creator as admin
        const memberQuery = `
            INSERT INTO group_members (group_id, user_id, role)
            VALUES ($1, $2, 'admin')
        `;

        await client.query(memberQuery, [group.id, created_by]);

        await client.query('COMMIT');

        res.status(201).json(group);

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}


async function getGroupById(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;

    try {
        const groupQuery = `
            SELECT g.*,
                   COUNT(DISTINCT gm.user_id) as member_count
            FROM groups g
            LEFT JOIN group_members gm ON g.id = gm.group_id
            WHERE g.id = $1 AND g.is_active = true
            GROUP BY g.id
        `;

        const groupResult = await pool.query(groupQuery, [group_id]);

        if (groupResult.rows.length === 0) {
            throw new Error('Group not found');
        }

        const group = groupResult.rows[0];

        // Check if user is member
        const memberCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const memberCheck = await pool.query(memberCheckQuery, [group_id, user_id]);
        const is_member = memberCheck.rows[0].is_member;

        if (!is_member) {
            // Return limited info for non-members
            res.send({
                id: group.id,
                name: group.name,
                description: group.description,
                avatar_url: group.avatar_url,
                member_count: group.member_count,
                is_member: false
            });
            return;
        }

        // Get members for group members
        const membersQuery = `
            SELECT 
                p.id,
                p.username,
                p.display_name,
                p.avatar_url,
                gm.role,
                gm.joined_at
            FROM group_members gm
            INNER JOIN profiles p ON gm.user_id = p.id
            WHERE gm.group_id = $1
            ORDER BY 
                CASE gm.role 
                    WHEN 'admin' THEN 1 
                    ELSE 2 
                END,
                gm.joined_at ASC
        `;

        const membersResult = await pool.query(membersQuery, [group_id]);

        // Check if user is admin
        const adminCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2 AND role = 'admin'
            ) as is_admin
        `;

        const adminCheck = await pool.query(adminCheckQuery, [group_id, user_id]);
        const is_admin = adminCheck.rows[0].is_admin;

        res.send({
            ...group,
            members: membersResult.rows,
            is_member: true,
            is_admin: is_admin
        });

    } catch (error) {
        throw error;
    }
}

async function updateGroup(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;
    const updates = req.body;

    try {
        // Check if user is admin
        const adminCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2 AND role = 'admin'
            ) as is_admin
        `;

        const adminCheck = await pool.query(adminCheckQuery, [group_id, user_id]);

        if (!adminCheck.rows[0].is_admin) {
            throw new Error('Only admins can update group details');
        }

        // Update group
        const query = `
            UPDATE groups
            SET name = $1, 
                description = $2, 
                avatar_url = $3, 
                settings = $4,
                updated_at = NOW()
            WHERE id = $5
            RETURNING *
        `;

        const values = [
            updates.name,
            updates.description || null,
            updates.avatar_url || null,
            updates.settings || {},
            group_id
        ];

        const result = await pool.query(query, values);

        if (result.rows.length === 0) {
            throw new Error('Group not found');
        }

        res.send(result.rows[0]);

    } catch (error) {
        throw error;
    }
}

async function deleteGroup(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is admin
        const adminCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2 AND role = 'admin'
            ) as is_admin
        `;

        const adminCheck = await pool.query(adminCheckQuery, [group_id, user_id]);

        if (!adminCheck.rows[0].is_admin) {
            throw new Error('Only admins can delete the group');
        }

        // Soft delete
        const query = `
            UPDATE groups
            SET is_active = false, updated_at = NOW()
            WHERE id = $1
            RETURNING id
        `;

        const result = await pool.query(query, [group_id]);

        if (result.rows.length === 0) {
            throw new Error('Group not found');
        }

        res.send({ message: 'Group deleted successfully' });

    } catch (error) {
        throw error;
    }
}

export { createGroup, getGroupById, updateGroup, deleteGroup };