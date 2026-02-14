import pool from '../database/pool.js';

/**
 * Create a timeline event
 * POST /api/timeline
 */
async function createEvent(req, res) {
    const user_id = req.user.id;
    const {
        group_id,
        title,
        description,
        event_date,
        location,
        event_type,
        cover_image_url,
        tags,
        participants
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

        // Create event
        const eventQuery = `
            INSERT INTO timeline_events (
                group_id, created_by, title, description, event_date,
                location, event_type, cover_image_url, tags
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        `;

        const eventValues = [
            group_id,
            user_id,
            title,
            description || null,
            event_date,
            location || null,
            event_type || 'memory',
            cover_image_url || null,
            tags || []
        ];

        const eventResult = await client.query(eventQuery, eventValues);
        const event = eventResult.rows[0];

        // Add creator as participant
        await client.query(
            'INSERT INTO timeline_event_participants (event_id, user_id, added_by) VALUES ($1, $2, $3)',
            [event.id, user_id, user_id]
        );

        // Add additional participants
        if (participants && participants.length > 0) {
            for (const participant_id of participants) {
                await client.query(
                    'INSERT INTO timeline_event_participants (event_id, user_id, added_by) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
                    [event.id, participant_id, user_id]
                );
            }
        }

        await client.query('COMMIT');

        res.status(201).send({
            success: true,
            data: { event },
            message: 'Timeline event created successfully'
        });

    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

/**
 * Get all timeline events for a group
 * GET /api/groups/:groupId/timeline
 */
async function getGroupTimeline(req, res) {
    const group_id = req.params.groupId;
    const user_id = req.user.id;
    const {
        year,
        month,
        event_type,
        tag,
        limit = 50,
        offset = 0
    } = req.query;

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
                te.*,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url,
                COUNT(DISTINCT tem.id) as media_count,
                COUNT(DISTINCT tem.id) FILTER (WHERE tem.media_type = 'photo') as photo_count,
                COUNT(DISTINCT tep.id) as participant_count,
                COUNT(DISTINCT tec.id) as comment_count,
                COUNT(DISTINCT ter.id) as reaction_count,
                json_agg(DISTINCT jsonb_build_object(
                    'id', tem.id,
                    'media_url', tem.media_url,
                    'thumbnail_url', tem.thumbnail_url,
                    'media_type', tem.media_type
                )) FILTER (WHERE tem.id IS NOT NULL) as preview_media
            FROM timeline_events te
            LEFT JOIN profiles p ON te.created_by = p.id
            LEFT JOIN timeline_event_media tem ON te.id = tem.event_id
            LEFT JOIN timeline_event_participants tep ON te.id = tep.event_id
            LEFT JOIN timeline_event_comments tec ON te.id = tec.event_id
            LEFT JOIN timeline_event_reactions ter ON te.id = ter.event_id
            WHERE te.group_id = $1
        `;

        const values = [group_id];
        let paramCount = 2;

        // Filters
        if (year) {
            query += ` AND EXTRACT(YEAR FROM te.event_date) = $${paramCount}`;
            values.push(parseInt(year));
            paramCount++;
        }

        if (month) {
            query += ` AND EXTRACT(MONTH FROM te.event_date) = $${paramCount}`;
            values.push(parseInt(month));
            paramCount++;
        }

        if (event_type) {
            query += ` AND te.event_type = $${paramCount}`;
            values.push(event_type);
            paramCount++;
        }

        if (tag) {
            query += ` AND $${paramCount} = ANY(te.tags)`;
            values.push(tag);
            paramCount++;
        }

        query += `
            GROUP BY te.id, p.username, p.display_name, p.avatar_url
            ORDER BY te.is_pinned DESC, te.event_date DESC, te.created_at DESC
            LIMIT $${paramCount} OFFSET $${paramCount + 1}
        `;

        values.push(parseInt(limit), parseInt(offset));

        const result = await pool.query(query, values);

        res.send({
            success: true,
            data: {
                events: result.rows,
                pagination: {
                    limit: parseInt(limit),
                    offset: parseInt(offset),
                    total: result.rows.length
                }
            }
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Get single timeline event with full details
 * GET /api/timeline/:id
 */
async function getEventById(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Get event with creator info
        const eventQuery = `
            SELECT 
                te.*,
                p.id as creator_id,
                p.username as creator_username,
                p.display_name as creator_display_name,
                p.avatar_url as creator_avatar_url
            FROM timeline_events te
            LEFT JOIN profiles p ON te.created_by = p.id
            WHERE te.id = $1
        `;

        const eventResult = await pool.query(eventQuery, [event_id]);

        if (eventResult.rows.length === 0) {
            throw new Error('Event not found');
        }

        const event = eventResult.rows[0];

        // Check if user is group member
        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [event.group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Get all media
        const mediaQuery = `
            SELECT 
                tem.*,
                p.username as uploader_username,
                p.display_name as uploader_display_name,
                p.avatar_url as uploader_avatar_url
            FROM timeline_event_media tem
            LEFT JOIN profiles p ON tem.uploaded_by = p.id
            WHERE tem.event_id = $1
            ORDER BY tem.order_index ASC, tem.uploaded_at ASC
        `;

        const mediaResult = await pool.query(mediaQuery, [event_id]);

        // Get participants
        const participantsQuery = `
            SELECT 
                tep.user_id,
                p.username,
                p.display_name,
                p.avatar_url,
                tep.added_at
            FROM timeline_event_participants tep
            INNER JOIN profiles p ON tep.user_id = p.id
            WHERE tep.event_id = $1
            ORDER BY tep.added_at ASC
        `;

        const participantsResult = await pool.query(participantsQuery, [event_id]);

        // Get comments with nested replies
        const commentsQuery = `
            WITH RECURSIVE comment_tree AS (
                -- Root comments
                SELECT 
                    tec.*,
                    p.username,
                    p.display_name,
                    p.avatar_url,
                    0 as depth,
                    ARRAY[tec.id] as path
                FROM timeline_event_comments tec
                LEFT JOIN profiles p ON tec.user_id = p.id
                WHERE tec.event_id = $1 AND tec.parent_comment_id IS NULL
                
                UNION ALL
                
                -- Child comments
                SELECT 
                    tec.*,
                    p.username,
                    p.display_name,
                    p.avatar_url,
                    ct.depth + 1,
                    ct.path || tec.id
                FROM timeline_event_comments tec
                LEFT JOIN profiles p ON tec.user_id = p.id
                INNER JOIN comment_tree ct ON tec.parent_comment_id = ct.id
                WHERE tec.event_id = $1
            )
            SELECT * FROM comment_tree
            ORDER BY path
        `;

        const commentsResult = await pool.query(commentsQuery, [event_id]);

        // Get reactions grouped by emoji
        const reactionsQuery = `
            SELECT 
                ter.emoji,
                json_agg(
                    json_build_object(
                        'id', p.id,
                        'username', p.username,
                        'display_name', p.display_name,
                        'avatar_url', p.avatar_url
                    ) ORDER BY ter.created_at
                ) as users
            FROM timeline_event_reactions ter
            INNER JOIN profiles p ON ter.user_id = p.id
            WHERE ter.event_id = $1
            GROUP BY ter.emoji
        `;

        const reactionsResult = await pool.query(reactionsQuery, [event_id]);

        // Get statistics
        const statsQuery = 'SELECT * FROM get_timeline_event_stats($1)';
        const statsResult = await pool.query(statsQuery, [event_id]);

        // Record view
        await pool.query(
            'INSERT INTO timeline_event_views (event_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [event_id, user_id]
        );

        // Format response
        const response = {
            ...event,
            creator: {
                id: event.creator_id,
                username: event.creator_username,
                display_name: event.creator_display_name,
                avatar_url: event.creator_avatar_url
            },
            media: mediaResult.rows,
            participants: participantsResult.rows,
            comments: commentsResult.rows,
            reactions: reactionsResult.rows,
            stats: statsResult.rows[0]
        };

        // Remove duplicate creator fields
        delete response.creator_id;
        delete response.creator_username;
        delete response.creator_display_name;
        delete response.creator_avatar_url;

        res.send({
            success: true,
            data: { event: response }
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Update timeline event
 * PUT /api/timeline/:id
 */
async function updateEvent(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;
    const {
        title,
        description,
        event_date,
        location,
        event_type,
        cover_image_url,
        tags
    } = req.body;

    try {
        // Check if user is creator
        const eventCheck = await pool.query(
            'SELECT created_by FROM timeline_events WHERE id = $1',
            [event_id]
        );

        if (eventCheck.rows.length === 0) {
            throw new Error('Event not found');
        }

        if (eventCheck.rows[0].created_by !== user_id) {
            throw new Error('Only the creator can update this event');
        }

        // Update event
        const query = `
            UPDATE timeline_events
            SET title = $1, description = $2, event_date = $3, location = $4,
                event_type = $5, cover_image_url = $6, tags = $7
            WHERE id = $8
            RETURNING *
        `;

        const values = [
            title,
            description || null,
            event_date,
            location || null,
            event_type || 'memory',
            cover_image_url || null,
            tags || [],
            event_id
        ];

        const result = await pool.query(query, values);

        res.send({
            success: true,
            data: { event: result.rows[0] }
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Delete timeline event
 * DELETE /api/timeline/:id
 */
async function deleteEvent(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is creator
        const eventCheck = await pool.query(
            'SELECT created_by FROM timeline_events WHERE id = $1',
            [event_id]
        );

        if (eventCheck.rows.length === 0) {
            throw new Error('Event not found');
        }

        if (eventCheck.rows[0].created_by !== user_id) {
            throw new Error('Only the creator can delete this event');
        }

        // Delete event (cascade deletes media, participants, comments, reactions)
        await pool.query('DELETE FROM timeline_events WHERE id = $1', [event_id]);

        res.send({
            success: true,
            message: 'Event deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Add media to event
 * POST /api/timeline/:id/media
 */
async function addMedia(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;
    const {
        media_type,
        media_url,
        thumbnail_url,
        caption,
        width,
        height,
        file_size_bytes,
        duration_seconds,
        order_index
    } = req.body;

    try {
        // Check if event exists and user is group member
        const eventCheck = await pool.query(
            `SELECT te.group_id 
             FROM timeline_events te
             WHERE te.id = $1`,
            [event_id]
        );

        if (eventCheck.rows.length === 0) {
            throw new Error('Event not found');
        }

        const memberCheck = await pool.query(
            'SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2) as is_member',
            [eventCheck.rows[0].group_id, user_id]
        );

        if (!memberCheck.rows[0].is_member) {
            throw new Error('You are not a member of this group');
        }

        // Add media
        const query = `
            INSERT INTO timeline_event_media (
                event_id, uploaded_by, media_type, media_url, thumbnail_url,
                caption, width, height, file_size_bytes, duration_seconds, order_index
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING *
        `;

        const values = [
            event_id,
            user_id,
            media_type,
            media_url,
            thumbnail_url || null,
            caption || null,
            width || null,
            height || null,
            file_size_bytes || null,
            duration_seconds || null,
            order_index || 0
        ];

        const result = await pool.query(query, values);

        res.status(201).send({
            success: true,
            data: { media: result.rows[0] },
            message: 'Media added to event'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Delete media from event
 * DELETE /api/timeline/:id/media/:mediaId
 */
async function deleteMedia(req, res) {
    const { id: event_id, mediaId } = req.params;
    const user_id = req.user.id;

    try {
        // Delete media (only if user uploaded it or is event creator)
        const query = `
            DELETE FROM timeline_event_media tem
            WHERE tem.id = $1 
              AND tem.event_id = $2
              AND (tem.uploaded_by = $3 OR EXISTS(
                  SELECT 1 FROM timeline_events te 
                  WHERE te.id = $2 AND te.created_by = $3
              ))
            RETURNING *
        `;

        const result = await pool.query(query, [mediaId, event_id, user_id]);

        if (result.rows.length === 0) {
            throw new Error('Media not found or unauthorized');
        }

        res.send({
            success: true,
            message: 'Media deleted successfully'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Add comment to event
 * POST /api/timeline/:id/comments
 */
async function addComment(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;
    const { comment_text, parent_comment_id } = req.body;

    try {
        const query = `
            INSERT INTO timeline_event_comments (event_id, user_id, comment_text, parent_comment_id)
            VALUES ($1, $2, $3, $4)
            RETURNING *
        `;

        const result = await pool.query(query, [
            event_id,
            user_id,
            comment_text,
            parent_comment_id || null
        ]);

        // Get user info
        const userQuery = `
            SELECT username, display_name, avatar_url
            FROM profiles WHERE id = $1
        `;
        const userResult = await pool.query(userQuery, [user_id]);

        res.status(201).send({
            success: true,
            data: {
                comment: {
                    ...result.rows[0],
                    ...userResult.rows[0]
                }
            },
            message: 'Comment added'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Delete comment
 * DELETE /api/timeline/:id/comments/:commentId
 */
async function deleteComment(req, res) {
    const { commentId } = req.params;
    const user_id = req.user.id;

    try {
        const query = `
            DELETE FROM timeline_event_comments
            WHERE id = $1 AND user_id = $2
            RETURNING *
        `;

        const result = await pool.query(query, [commentId, user_id]);

        if (result.rows.length === 0) {
            throw new Error('Comment not found or unauthorized');
        }

        res.send({
            success: true,
            message: 'Comment deleted'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Add reaction to event
 * POST /api/timeline/:id/reactions
 */
async function addReaction(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;
    const { emoji } = req.body;

    try {
        const query = `
            INSERT INTO timeline_event_reactions (event_id, user_id, emoji)
            VALUES ($1, $2, $3)
            ON CONFLICT (event_id, user_id) 
            DO UPDATE SET emoji = $3
            RETURNING *
        `;

        const result = await pool.query(query, [event_id, user_id, emoji]);

        res.send({
            success: true,
            data: { reaction: result.rows[0] },
            message: 'Reaction added'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Remove reaction
 * DELETE /api/timeline/:id/reactions
 */
async function removeReaction(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;

    try {
        const query = `
            DELETE FROM timeline_event_reactions
            WHERE event_id = $1 AND user_id = $2
            RETURNING *
        `;

        const result = await pool.query(query, [event_id, user_id]);

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

/**
 * Pin/Unpin event
 * PATCH /api/timeline/:id/pin
 */
async function togglePin(req, res) {
    const event_id = req.params.id;
    const user_id = req.user.id;

    try {
        // Check if user is creator
        const eventCheck = await pool.query(
            'SELECT created_by, is_pinned FROM timeline_events WHERE id = $1',
            [event_id]
        );

        if (eventCheck.rows.length === 0) {
            throw new Error('Event not found');
        }

        if (eventCheck.rows[0].created_by !== user_id) {
            throw new Error('Only the creator can pin/unpin this event');
        }

        const query = `
            UPDATE timeline_events
            SET is_pinned = NOT is_pinned
            WHERE id = $1
            RETURNING *
        `;

        const result = await pool.query(query, [event_id]);

        res.send({
            success: true,
            data: { event: result.rows[0] },
            message: result.rows[0].is_pinned ? 'Event pinned' : 'Event unpinned'
        });

    } catch (error) {
        throw error;
    }
}

/**
 * Search timeline events
 * GET /api/groups/:groupId/timeline/search
 */
async function searchEvents(req, res) {
    const group_id = req.params.groupId;
    const { q } = req.query;

    try {
        if (!q || q.trim().length < 2) {
            throw new Error('Search query must be at least 2 characters');
        }

        const query = 'SELECT * FROM search_timeline_events($1, $2)';
        const result = await pool.query(query, [group_id, q.trim()]);

        res.send({
            success: true,
            data: { events: result.rows }
        });

    } catch (error) {
        throw error;
    }
}

export {
    createEvent,
    getGroupTimeline,
    getEventById,
    updateEvent,
    deleteEvent,
    addMedia,
    deleteMedia,
    addComment,
    deleteComment,
    addReaction,
    removeReaction,
    togglePin,
    searchEvents
};