import pool from '../database/pool.js';

async function createCapsule(req, res) {
    const user_id = req.user.id;
    const {
        group_id,
        title,
        description,
        unlock_date,
        is_collaborative,
        contribution_deadline,
        thumbnail_url,
        theme,
        contributors
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

        // Validate unlock date is in future
        const unlockDate = new Date(unlock_date);
        if (unlockDate <= new Date()) {
            throw new Error('Unlock date must be in the future');
        }

        // Create capsule
        const capsuleQuery = `
            INSERT INTO time_capsules (
                group_id, created_by, title, description, unlock_date,
                is_collaborative, contribution_deadline, thumbnail_url, theme
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        `;

        const capsuleValues = [
            group_id,
            user_id,
            title,
            description || null,
            unlock_date,
            is_collaborative || false,
            contribution_deadline || null,
            thumbnail_url || null,
            theme || 'default'
        ];

        const capsuleResult = await client.query(capsuleQuery, capsuleValues);
        const capsule = capsuleResult.rows[0];

        // Add creator as contributor
        await client.query(
            'INSERT INTO capsule_contributors (capsule_id, user_id) VALUES ($1, $2)',
            [capsule.id, user_id]
        );

        // Add additional contributors if collaborative
        if (is_collaborative && contributors && contributors.length > 0) {
            for (const contributor_id of contributors) {
                await client.query(
                    'INSERT INTO capsule_contributors (capsule_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
                    [capsule.id, contributor_id]
                );
            }
        }

        await client.query('COMMIT');

        res.status(201).send({
            success: true,
            data: { capsule },
            message: 'Time capsule created successfully'
        });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}


async function getCapsuleById(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Get capsule with creator info
        const capsuleQuery = `
            SELECT 
                tc.*,
                p.id as creator_id,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url
            FROM time_capsules tc
            LEFT JOIN profiles p ON tc.created_by = p.id
            WHERE tc.id = $1
        `;

        const capsuleResult = await pool.query(capsuleQuery, [capsule_id]);

        if (capsuleResult.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        const capsule = capsuleResult.rows[0];

        // Check if user is group member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [capsule.group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Get contributors
        const contributorsQuery = `
            SELECT 
                cc.user_id,
                p.username,
                p.display_name,
                p.avatar_url,
                cc.has_contributed,
                cc.contributed_at
            FROM capsule_contributors cc
            LEFT JOIN profiles p ON cc.user_id = p.id
            WHERE cc.capsule_id = $1
        `;

        const contributorsResult = await pool.query(contributorsQuery, [capsule_id]);

        // Get contents if unlocked
        let contents = [];
        if (!capsule.is_locked) {
            const contentsQuery = `
                SELECT 
                    cc.*,
                    p.id as user_id,
                    p.username,
                    p.display_name,
                    p.avatar_url
                FROM capsule_contents cc
                LEFT JOIN profiles p ON cc.user_id = p.id
                WHERE cc.capsule_id = $1
                ORDER BY cc.order_index ASC, cc.created_at ASC
            `;

            const contentsResult = await pool.query(contentsQuery, [capsule_id]);
            contents = contentsResult.rows;

            // Record view
            await pool.query(
                'INSERT INTO capsule_views (capsule_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
                [capsule_id, user_id]
            );
        }

        // Get reactions
        const reactionsQuery = `
            SELECT 
                cr.emoji,
                json_agg(
                    json_build_object(
                        'id', p.id,
                        'username', p.username,
                        'display_name', p.display_name,
                        'avatar_url', p.avatar_url
                    )
                ) as users
            FROM capsule_reactions cr
            INNER JOIN profiles p ON cr.user_id = p.id
            WHERE cr.capsule_id = $1
            GROUP BY cr.emoji
        `;

        const reactionsResult = await pool.query(reactionsQuery, [capsule_id]);

        // Check if user is contributor
        const isContributor = contributorsResult.rows.some(c => c.user_id === user_id);

        // Format response
        const response = {
            id: capsule.id,
            group_id: capsule.group_id,
            title: capsule.title,
            description: capsule.description,
            unlock_date: capsule.unlock_date,
            is_locked: capsule.is_locked,
            is_collaborative: capsule.is_collaborative,
            contribution_deadline: capsule.contribution_deadline,
            thumbnail_url: capsule.thumbnail_url,
            theme: capsule.theme,
            created_at: capsule.created_at,
            unlocked_at: capsule.unlocked_at,
            views_count: capsule.views_count,
            is_read_only: capsule.is_read_only,
            creator: {
                id: capsule.creator_id,
                username: capsule.creator_username,
                display_name: capsule.creator_display_name,
                avatar_url: capsule.creator_avatar_url
            },
            contributors: contributorsResult.rows,
            contents: contents,
            reactions: reactionsResult.rows,
            is_contributor: isContributor
        };

        res.send({
            success: true,
            data: { capsule: response }
        });

    } catch (error) {
        throw error;
    }
}

async function getGroupCapsules(req, res) {
    const group_id = req.params.groupId;
    const user_id = req.user.id;
    const { include_unlocked = 'true' } = req.query;

    try {
        // Check if user is group member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        let query = `
            SELECT 
                tc.*,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url,
                COUNT(DISTINCT cc.id) as content_count,
                COUNT(DISTINCT contrib.id) as contributor_count,
                COUNT(DISTINCT contrib.id) FILTER (WHERE contrib.has_contributed = true) as contributed_count
            FROM time_capsules tc
            LEFT JOIN profiles p ON tc.created_by = p.id
            LEFT JOIN capsule_contents cc ON tc.id = cc.capsule_id
            LEFT JOIN capsule_contributors contrib ON tc.id = contrib.capsule_id
            WHERE tc.group_id = $1
        `;

        if (include_unlocked !== 'true') {
            query += ` AND tc.is_locked = true`;
        }

        query += `
            GROUP BY tc.id, p.username, p.display_name, p.avatar_url
            ORDER BY tc.unlock_date ASC
        `;

        const result = await pool.query(query, [group_id]);

        res.send({
            success: true,
            data: { capsules: result.rows }
        });

    } catch (error) {
        throw error;
    }
}

async function updateCapsule(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;
    const { title, description, thumbnail_url, theme } = req.body;

    try {
        // Check if user is creator
        const capsuleCheck = await pool.query(
            'SELECT created_by, is_locked, is_read_only FROM time_capsules WHERE id = $1',
            [capsule_id]
        );

        if (capsuleCheck.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        const capsule = capsuleCheck.rows[0];

        if (capsule.created_by !== user_id) {
            throw new Error('Only the creator can update this capsule');
        }

        if (!capsule.is_locked || capsule.is_read_only) {
            throw new Error('Capsule cannot be edited (already unlocked or read-only)');
        }

        // Update capsule
        const query = `
            UPDATE time_capsules
            SET title = $1, description = $2, thumbnail_url = $3, theme = $4
            WHERE id = $5
            RETURNING *
        `;

        const result = await pool.query(query, [
            title,
            description || null,
            thumbnail_url || null,
            theme || 'default',
            capsule_id
        ]);

        res.send({
            success: true,
            data: { capsule: result.rows[0] }
        });

    } catch (error) {
        throw error;
    }
}


async function deleteCapsule(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is creator and capsule is locked
        const capsuleCheck = await pool.query(
            'SELECT created_by, is_locked FROM time_capsules WHERE id = $1',
            [capsule_id]
        );

        if (capsuleCheck.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        const capsule = capsuleCheck.rows[0];

        if (capsule.created_by !== user_id) {
            throw new Error('Only the creator can delete this capsule');
        }

        if (!capsule.is_locked) {
            throw new Error('Cannot delete unlocked capsules');
        }

        // Delete capsule
        await pool.query('DELETE FROM time_capsules WHERE id = $1', [capsule_id]);

        res.send({
            success: true,
            message: 'Capsule deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

async function addContent(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;
    const {
        content_type,
        content_text,
        media_url,
        media_thumbnail_url,
        duration_seconds,
        file_size_bytes,
        metadata,
        order_index
    } = req.body;

    try {
        // Get capsule info
        const capsuleQuery = `
            SELECT 
                tc.*,
                EXISTS(SELECT 1 FROM capsule_contributors WHERE capsule_id = tc.id AND user_id = $2) as is_contributor
            FROM time_capsules tc
            WHERE tc.id = $1
        `;

        const capsuleResult = await pool.query(capsuleQuery, [capsule_id, user_id]);

        if (capsuleResult.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        const capsule = capsuleResult.rows[0];

        // Check if capsule is locked
        if (!capsule.is_locked) {
            throw new Error('Cannot add content to unlocked capsule');
        }

        // Check permissions
        if (!capsule.is_collaborative && capsule.created_by !== user_id) {
            throw new Error('Only the creator can add content to this capsule');
        }

        if (capsule.is_collaborative && !capsule.is_contributor) {
            throw new Error('You are not a contributor to this capsule');
        }

        // Check contribution deadline
        if (capsule.contribution_deadline && new Date() > new Date(capsule.contribution_deadline)) {
            throw new Error('Contribution deadline has passed');
        }

        // Validate content type
        if (!['photo', 'note', 'voice', 'video'].includes(content_type)) {
            throw new Error('Invalid content type');
        }

        // Insert content
        const contentQuery = `
            INSERT INTO capsule_contents (
                capsule_id, user_id, content_type, content_text,
                media_url, media_thumbnail_url, duration_seconds,
                file_size_bytes, metadata, order_index
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING *
        `;

        const contentValues = [
            capsule_id,
            user_id,
            content_type,
            content_text || null,
            media_url || null,
            media_thumbnail_url || null,
            duration_seconds || null,
            file_size_bytes || null,
            metadata || {},
            order_index || 0
        ];

        const result = await pool.query(contentQuery, contentValues);

        res.status(201).send({
            success: true,
            data: { content: result.rows[0] },
            message: 'Content added to capsule'
        });

    } catch (error) {
        throw error;
    }
}

async function deleteContent(req, res) {
    const { id: capsule_id, contentId } = req.params;
    const user_id = req.user.id;

    try {
        // Check if capsule is locked
        const capsuleCheck = await pool.query(
            'SELECT is_locked FROM time_capsules WHERE id = $1',
            [capsule_id]
        );

        if (capsuleCheck.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        if (!capsuleCheck.rows[0].is_locked) {
            throw new Error('Cannot delete content from unlocked capsule');
        }

        // Delete content (only if user owns it)
        const deleteQuery = `
            DELETE FROM capsule_contents
            WHERE id = $1 AND user_id = $2 AND capsule_id = $3
            RETURNING *
        `;

        const result = await pool.query(deleteQuery, [contentId, user_id, capsule_id]);

        if (result.rows.length === 0) {
            throw new Error('Content not found or unauthorized');
        }

        res.send({
            success: true,
            message: 'Content deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

async function addReaction(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;
    const { emoji } = req.body;

    try {
        // Check if capsule is unlocked
        const capsuleCheck = await pool.query(
            'SELECT is_locked FROM time_capsules WHERE id = $1',
            [capsule_id]
        );

        if (capsuleCheck.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        if (capsuleCheck.rows[0].is_locked) {
            throw new Error('Cannot react to locked capsule');
        }

        // Add/update reaction
        const query = `
            INSERT INTO capsule_reactions (capsule_id, user_id, emoji)
            VALUES ($1, $2, $3)
            ON CONFLICT (capsule_id, user_id) 
            DO UPDATE SET emoji = $3
            RETURNING *
        `;

        const result = await pool.query(query, [capsule_id, user_id, emoji]);

        res.send({
            success: true,
            data: { reaction: result.rows[0] },
            message: 'Reaction added'
        });

    } catch (error) {
        throw error;
    }
}

async function removeReaction(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;

    try {
        const query = `
            DELETE FROM capsule_reactions
            WHERE capsule_id = $1 AND user_id = $2
            RETURNING *
        `;

        const result = await pool.query(query, [capsule_id, user_id]);

        if (result.rows.length === 0) {
            throw new Error('Reaction not found');
        }

        res.send({
            success: true,
            message: 'Reaction removed'
        });

    } catch (error) {
        throw error;
    }
}


async function unlockCapsule(req, res) {
    const capsule_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is creator
        const capsuleCheck = await pool.query(
            'SELECT created_by, is_locked FROM time_capsules WHERE id = $1',
            [capsule_id]
        );

        if (capsuleCheck.rows.length === 0) {
            throw new Error('Capsule not found');
        }

        const capsule = capsuleCheck.rows[0];

        if (capsule.created_by !== user_id) {
            throw new Error('Only the creator can unlock this capsule');
        }

        if (!capsule.is_locked) {
            throw new Error('Capsule is already unlocked');
        }

        // Unlock capsule
        const query = `
            UPDATE time_capsules
            SET is_locked = false
            WHERE id = $1
            RETURNING *
        `;

        const result = await pool.query(query, [capsule_id]);

        res.send({
            success: true,
            data: { capsule: result.rows[0] },
            message: 'Capsule unlocked successfully'
        });

    } catch (error) {
        throw error;
    }
}

export {
    createCapsule,
    getCapsuleById,
    getGroupCapsules,
    updateCapsule,
    deleteCapsule,
    addContent,
    deleteContent,
    addReaction,
    removeReaction,
    unlockCapsule
};