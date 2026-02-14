import pool from "../database/pool.js";

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

async function joinGroup(req, res) {
    const { invite_code } = req.body;
    const user_id = req.user.id;

    try {
        // Find group by invite code
        const groupQuery = `
            SELECT * FROM groups 
            WHERE invite_code = $1 AND is_active = true
        `;

        const groupResult = await pool.query(groupQuery, [invite_code]);

        if (groupResult.rows.length === 0) {
            throw new Error('Invalid invite code');
        }

        const group = groupResult.rows[0];

        // Check if already a member
        const memberCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const memberCheck = await pool.query(memberCheckQuery, [group.id, user_id]);

        if (memberCheck.rows[0].is_member) {
            throw new Error('You are already a member of this group');
        }

        // Add member
        const addMemberQuery = `
            INSERT INTO group_members (group_id, user_id)
            VALUES ($1, $2)
        `;

        await pool.query(addMemberQuery, [group.id, user_id]);

        res.send({
            message: 'Joined group successfully',
            group: group
        });

    } catch (error) {
        throw error;
    }
}

async function leaveGroup(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Check if user is member
        const memberCheckQuery = `
            SELECT role FROM group_members
            WHERE group_id = $1 AND user_id = $2
        `;

        const memberCheck = await client.query(memberCheckQuery, [group_id, user_id]);

        if (memberCheck.rows.length === 0) {
            throw new Error('You are not a member of this group');
        }

        const user_role = memberCheck.rows[0].role;

        // If user is admin, check if they're the only admin
        if (user_role === 'admin') {
            const adminCountQuery = `
                SELECT COUNT(*) as admin_count
                FROM group_members
                WHERE group_id = $1 AND role = 'admin'
            `;

            const adminCount = await client.query(adminCountQuery, [group_id]);

            if (parseInt(adminCount.rows[0].admin_count) === 1) {
                throw new Error('Cannot leave: You are the only admin. Assign another admin first.');
            }
        }

        // Remove member
        const removeQuery = `
            DELETE FROM group_members
            WHERE group_id = $1 AND user_id = $2
        `;

        await client.query(removeQuery, [group_id, user_id]);

        await client.query('COMMIT');

        res.send({ message: 'Left group successfully' });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

async function getGroupMembers(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is member
        const memberCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const memberCheck = await pool.query(memberCheckQuery, [group_id, user_id]);

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You must be a member to view group members');
        }

        // Get members
        const query = `
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

        const result = await pool.query(query, [group_id]);
        res.send(result.rows);

    } catch (error) {
        throw error;
    }
}

async function removeMember(req, res) {
    const group_id = req.params.id;
    const member_id = req.params.memberId;
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
            throw new Error('Only admins can remove members');
        }

        // Cannot remove yourself (use leave endpoint)
        if (user_id === member_id) {
            throw new Error('Use the leave endpoint to remove yourself');
        }

        // Remove member
        const query = `
            DELETE FROM group_members
            WHERE group_id = $1 AND user_id = $2
            RETURNING *
        `;

        const result = await pool.query(query, [group_id, member_id]);

        if (result.rows.length === 0) {
            throw new Error('Member not found');
        }

        res.send({ message: 'Member removed successfully' });

    } catch (error) {
        throw error;
    }
}

async function createJoinRequest(req, res) {
    const group_id = req.params.id;
    const user_id = req.user.id;
    const { message } = req.body;

    try {
        // Check if group exists
        const groupCheckQuery = `
            SELECT EXISTS(SELECT 1 FROM groups WHERE id = $1 AND is_active = true) as exists
        `;

        const groupCheck = await pool.query(groupCheckQuery, [group_id]);

        if (!groupCheck.rows[0].exists) {
            throw new Error('Group not found');
        }

        // Check if already a member
        const memberCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const memberCheck = await pool.query(memberCheckQuery, [group_id, user_id]);

        if (memberCheck.rows[0].is_member) {
            throw new Error('You are already a member of this group');
        }

        // Create or update join request
        const query = `
            INSERT INTO group_join_requests (group_id, requester_id, message, status)
            VALUES ($1, $2, $3, 'pending')
            ON CONFLICT (group_id, requester_id, status) 
            DO UPDATE SET message = $3, created_at = NOW()
            RETURNING *
        `;

        const result = await pool.query(query, [group_id, user_id, message || null]);

        res.send({
            message: 'Join request sent',
            request: result.rows[0]
        });

    } catch (error) {
        throw error;
    }
}

async function getJoinRequests(req, res) {
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
            throw new Error('Only admins can view join requests');
        }

        // Get pending requests
        const query = `
            SELECT 
                gjr.*,
                p.id as requester_id,
                p.username as requester_username,
                p.display_name as requester_display_name,
                p.avatar_url as requester_avatar_url
            FROM group_join_requests gjr
            INNER JOIN profiles p ON gjr.requester_id = p.id
            WHERE gjr.group_id = $1 AND gjr.status = 'pending'
            ORDER BY gjr.created_at DESC
        `;

        const result = await pool.query(query, [group_id]);
        res.send(result.rows);

    } catch (error) {
        throw error;
    }
}

async function respondToJoinRequest(req, res) {
    const request_id = req.params.requestId;
    const user_id = req.user.id;
    const { status } = req.body;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Validate status
        if (!['approved', 'rejected'].includes(status)) {
            throw new Error('Invalid status. Must be "approved" or "rejected"');
        }

        // Get request details
        const getRequestQuery = `
            SELECT * FROM group_join_requests WHERE id = $1
        `;

        const requestResult = await client.query(getRequestQuery, [request_id]);

        if (requestResult.rows.length === 0) {
            throw new Error('Join request not found');
        }

        const request = requestResult.rows[0];

        // Check if user is admin of the group
        const adminCheckQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2 AND role = 'admin'
            ) as is_admin
        `;

        const adminCheck = await client.query(adminCheckQuery, [request.group_id, user_id]);

        if (!adminCheck.rows[0].is_admin) {
            throw new Error('Only admins can respond to join requests');
        }

        // Update request status
        const updateQuery = `
            UPDATE group_join_requests
            SET status = $2, responded_by = $3, responded_at = NOW()
            WHERE id = $1
            RETURNING *
        `;

        const updateResult = await client.query(updateQuery, [request_id, status, user_id]);

        // If approved, add member to group
        if (status === 'approved') {
            await client.query(
                'INSERT INTO group_members (group_id, user_id) VALUES ($1, $2)',
                [request.group_id, request.requester_id]
            );
        }

        await client.query('COMMIT');

        res.send({
            message: `Request ${status}`,
            request: updateResult.rows[0]
        });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}




export { createGroup, getGroupById, updateGroup, deleteGroup, joinGroup, leaveGroup, getGroupMembers, removeMember, createJoinRequest, getJoinRequests, respondToJoinRequest };
