import pool from '../database/pool.js';

/**
 * Get chat history for a group
 * GET /api/chat/:groupId/messages
 */
async function getChatHistory(req, res) {
    const group_id = req.params.groupId;
    const user_id = req.user.id;
    const { limit = 50, before } = req.query; // Pagination

    try {
        // Check if user is member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Get messages
        let query = `
            SELECT 
                cm.*,
                p.id as sender_id,
                p.username as sender_username,
                p.display_name as sender_display_name,
                p.avatar_url as sender_avatar_url,
                (
                    SELECT json_agg(json_build_object(
                        'userId', mrr.user_id,
                        'readAt', mrr.read_at
                    ))
                    FROM message_read_receipts mrr
                    WHERE mrr.message_id = cm.id
                ) as read_by
            FROM chat_messages cm
            LEFT JOIN profiles p ON cm.sender_id = p.id
            WHERE cm.group_id = $1 AND cm.is_deleted = false
        `;

        const values = [group_id];
        let paramCount = 2;

        if (before) {
            query += ` AND cm.created_at < $${paramCount}`;
            values.push(before);
            paramCount++;
        }

        query += ` ORDER BY cm.created_at DESC LIMIT $${paramCount}`;
        values.push(parseInt(limit));

        const result = await pool.query(query, values);

        // Format messages
        const messages = result.rows.map(row => ({
            id: row.id,
            groupId: row.group_id,
            sender: {
                id: row.sender_id,
                username: row.sender_username,
                displayName: row.sender_display_name,
                avatarUrl: row.sender_avatar_url
            },
            messageType: row.message_type,
            content: row.content,
            mediaUrl: row.media_url,
            replyToId: row.reply_to_id,
            isEdited: row.is_edited,
            createdAt: row.created_at,
            readBy: row.read_by || []
        })).reverse(); // Reverse to get chronological order

        res.send({
            success: true,
            data: { messages }
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Get unread message count for user
 * GET /api/chat/unread
 */
async function getUnreadCount(req, res) {
    const user_id = req.user.id;

    try {
        const query = `
            SELECT 
                cm.group_id,
                COUNT(*) as unread_count
            FROM chat_messages cm
            INNER JOIN group_members gm ON cm.group_id = gm.group_id
            WHERE gm.user_id = $1 
                AND cm.sender_id != $1
                AND cm.is_deleted = false
                AND NOT EXISTS (
                    SELECT 1 FROM message_read_receipts mrr
                    WHERE mrr.message_id = cm.id AND mrr.user_id = $1
                )
            GROUP BY cm.group_id
        `;

        const result = await pool.query(query, [user_id]);

        res.send({
            success: true,
            data: { unreadCounts: result.rows }
        });

    } catch (error) {
        throw error;
    }
}

export { getChatHistory, getUnreadCount };