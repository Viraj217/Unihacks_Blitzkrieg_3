import pool from '../database/pool.js';

async function createVault(req, res) {
    const user_id = req.user.id;
    const {
        group_id,
        name,
        description,
        is_private,
        avatar_url,
        initial_message
    } = req.body;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Check if user is group member
        const memberCheck = await client.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Create vault
        const vaultQuery = `
            INSERT INTO vaults (
                group_id, created_by, name, description, is_private, avatar_url
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `;

        const vaultValues = [
            group_id,
            user_id,
            name,
            description || null,
            is_private || false,
            avatar_url || null
        ];

        const vaultResult = await client.query(vaultQuery, vaultValues);
        const vault = vaultResult.rows[0];

        // If user provided an initial message, add it to the vault
        const messageText = typeof initial_message === 'string' ? initial_message.trim() : '';
        if (messageText.length > 0) {
            const messageQuery = `
                INSERT INTO vault_messages (
                    vault_id, sender_id, message_type, content
                )
                VALUES ($1, $2, 'text', $3)
                RETURNING *
            `;
            await client.query(messageQuery, [vault.id, user_id, messageText]);
            await client.query(
                'UPDATE vaults SET updated_at = NOW() WHERE id = $1',
                [vault.id]
            );
        }

        await client.query('COMMIT');

        res.status(201).send({
            success: true,
            data: { vault },
            message: 'Vault created successfully'
        });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

async function getVaultById(req, res) {
    const vault_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Get vault with creator info
        const vaultQuery = `
            SELECT 
                v.*,
                p.id as creator_id,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url
            FROM vaults v
            LEFT JOIN profiles p ON v.created_by = p.id
            WHERE v.id = $1
        `;

        const vaultResult = await pool.query(vaultQuery, [vault_id]);

        if (vaultResult.rows.length === 0) {
            throw new Error('Vault not found');
        }

        const vault = vaultResult.rows[0];

        // Check if user is group member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [vault.group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Get messages
        const messagesQuery = `
            SELECT 
                vm.*,
                p.id as sender_id,
                p.username as sender_username,
                p.display_name as sender_display_name,
                p.avatar_url as sender_avatar_url
            FROM vault_messages vm
            LEFT JOIN profiles p ON vm.sender_id = p.id
            WHERE vm.vault_id = $1 AND vm.is_deleted = false
            ORDER BY vm.created_at ASC
        `;

        const messagesResult = await pool.query(messagesQuery, [vault_id]);

        // Format response
        const response = {
            id: vault.id,
            group_id: vault.group_id,
            name: vault.name,
            description: vault.description,
            is_private: vault.is_private,
            avatar_url: vault.avatar_url,
            created_at: vault.created_at,
            updated_at: vault.updated_at,
            creator: {
                id: vault.creator_id,
                username: vault.creator_username,
                display_name: vault.creator_display_name,
                avatar_url: vault.creator_avatar_url
            },
            messages: messagesResult.rows
        };

        res.send({
            success: true,
            data: { vault: response }
        });

    } catch (error) {
        throw error;
    }
}

async function getGroupVaults(req, res) {
    const group_id = req.params.groupId;
    const user_id = req.user.id;

    try {
        // Check if user is group member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        const query = `
            SELECT 
                v.*,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url,
                COUNT(DISTINCT vm.id) as message_count
            FROM vaults v
            LEFT JOIN profiles p ON v.created_by = p.id
            LEFT JOIN vault_messages vm ON v.id = vm.vault_id AND vm.is_deleted = false
            WHERE v.group_id = $1
            GROUP BY v.id, p.username, p.display_name, p.avatar_url
            ORDER BY v.created_at DESC
        `;

        const result = await pool.query(query, [group_id]);

        res.send({
            success: true,
            data: { vaults: result.rows }
        });

    } catch (error) {
        throw error;
    }
}

async function addMessage(req, res) {
    const vault_id = req.params.id;
    const user_id = req.user.id;
    const {
        message_type,
        content,
        media_url,
        reply_to_id
    } = req.body;

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // Get vault info and check permissions
        const vaultQuery = `
            SELECT 
                v.*,
                EXISTS(SELECT 1 FROM group_members WHERE group_id = v.group_id AND user_id = $2) as is_member
            FROM vaults v
            WHERE v.id = $1
        `;

        const vaultResult = await client.query(vaultQuery, [vault_id, user_id]);

        if (vaultResult.rows.length === 0) {
            throw new Error('Vault not found');
        }

        const vault = vaultResult.rows[0];

        if (!vault.is_member) {
            throw new Error('You are not a member of this group');
        }

        // Validate reply_to_id if provided
        if (reply_to_id) {
            const replyCheck = await client.query(
                'SELECT id FROM vault_messages WHERE id = $1 AND vault_id = $2 AND is_deleted = false',
                [reply_to_id, vault_id]
            );

            if (replyCheck.rows.length === 0) {
                throw new Error('Reply message not found');
            }
        }

        // Validate content
        if (!content && !media_url) {
            throw new Error('Message must have either content or media');
        }

        // Validate message type
        if (!['text', 'image', 'voice', 'video', 'file'].includes(message_type)) {
            throw new Error('Invalid message type');
        }

        // Insert message
        const messageQuery = `
            INSERT INTO vault_messages (
                vault_id, sender_id, message_type, content,
                media_url, reply_to_id
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `;

        const messageValues = [
            vault_id,
            user_id,
            message_type || 'text',
            content || null,
            media_url || null,
            reply_to_id || null
        ];

        const messageResult = await client.query(messageQuery, messageValues);
        const message = messageResult.rows[0];

        // Update vault's updated_at timestamp
        await client.query(
            'UPDATE vaults SET updated_at = NOW() WHERE id = $1',
            [vault_id]
        );

        await client.query('COMMIT');

        // Get sender info for response
        const senderQuery = `
            SELECT id, username, display_name, avatar_url
            FROM profiles
            WHERE id = $1
        `;

        const senderResult = await pool.query(senderQuery, [user_id]);

        const response = {
            ...message,
            sender: senderResult.rows[0]
        };

        res.status(201).send({
            success: true,
            data: { message: response },
            message: 'Message added to vault successfully'
        });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

async function updateMessage(req, res) {
    const { id: vault_id, messageId } = req.params;
    const user_id = req.user.id;
    const { content, media_url } = req.body;

    try {
        // Check if message exists and user owns it
        const messageCheck = await pool.query(
            'SELECT sender_id FROM vault_messages WHERE id = $1 AND vault_id = $2 AND is_deleted = false',
            [messageId, vault_id]
        );

        if (messageCheck.rows.length === 0) {
            throw new Error('Message not found');
        }

        if (messageCheck.rows[0].sender_id !== user_id) {
            throw new Error('You can only edit your own messages');
        }

        // Update message
        const query = `
            UPDATE vault_messages
            SET content = $1, media_url = $2, is_edited = true, updated_at = NOW()
            WHERE id = $3 AND vault_id = $4
            RETURNING *
        `;

        const result = await pool.query(query, [
            content || null,
            media_url || null,
            messageId,
            vault_id
        ]);

        res.send({
            success: true,
            data: { message: result.rows[0] },
            message: 'Message updated successfully'
        });

    } catch (error) {
        throw error;
    }
}

async function deleteMessage(req, res) {
    const { id: vault_id, messageId } = req.params;
    const user_id = req.user.id;

    try {
        // Check if message exists and user owns it
        const messageCheck = await pool.query(
            'SELECT sender_id FROM vault_messages WHERE id = $1 AND vault_id = $2 AND is_deleted = false',
            [messageId, vault_id]
        );

        if (messageCheck.rows.length === 0) {
            throw new Error('Message not found');
        }

        if (messageCheck.rows[0].sender_id !== user_id) {
            throw new Error('You can only delete your own messages');
        }

        // Soft delete message
        await pool.query(
            'UPDATE vault_messages SET is_deleted = true, updated_at = NOW() WHERE id = $1 AND vault_id = $2',
            [messageId, vault_id]
        );

        res.send({
            success: true,
            message: 'Message deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

async function deleteVault(req, res) {
    const vault_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is creator
        const vaultCheck = await pool.query(
            'SELECT created_by FROM vaults WHERE id = $1',
            [vault_id]
        );

        if (vaultCheck.rows.length === 0) {
            throw new Error('Vault not found');
        }

        if (vaultCheck.rows[0].created_by !== user_id) {
            throw new Error('Only the creator can delete this vault');
        }

        // Delete vault (cascade will delete messages)
        await pool.query('DELETE FROM vaults WHERE id = $1', [vault_id]);

        res.send({
            success: true,
            message: 'Vault deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

export {
    createVault,
    getVaultById,
    getGroupVaults,
    addMessage,
    updateMessage,
    deleteMessage,
    deleteVault
};
