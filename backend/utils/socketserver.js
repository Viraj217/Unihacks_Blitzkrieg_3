import { Server } from 'socket.io';
import pool from '../database/pool.js';
import supabase from '../config/supabase.js';
import {
    ensureBotProfile,
    handleMention,
    checkForRoast,
    saveBotMessage,
    buildBotPayload,
    GEMINI_BOT_ID,
} from './gemini.js';
import { truths, dares, sikeQuestions } from '../utils/gameData.js';

let io;

function initializeSocket(httpServer) {
    io = new Server(httpServer, {
        cors: {
            origin: process.env.CORS_ORIGIN?.split(',') || '*',
            methods: ['GET', 'POST'],
            credentials: true
        },
        pingTimeout: 60000,
        pingInterval: 25000
    });

    // Authentication middleware
    io.use(async (socket, next) => {
        try {
            const token = socket.handshake.auth.token;

            if (!token) {
                return next(new Error('Authentication error: No token provided'));
            }

            const { data, error } = await supabase.auth.getUser(token);

            if (error || !data.user) {
                return next(new Error("Invalid token"));
            }

            socket.user = data.user; // Attach user to socket
            next();
        } catch (error) {
            next(new Error('Authentication error: Invalid token'));
        }
    });

    // Connection handler
    // Ensure Gemini bot profile exists on startup
    ensureBotProfile();

    io.on('connection', (socket) => {
        console.log(`✅ User connected: ${socket.user.username} (${socket.id})`);

        // Join user's personal room
        socket.join(`user:${socket.user.id}`);

        // Join user's groups
        joinUserGroups(socket);

        // Handle group join
        socket.on('join:group', async (groupId) => {
            await handleJoinGroup(socket, groupId);
        });

        // Handle group leave
        socket.on('leave:group', (groupId) => {
            handleLeaveGroup(socket, groupId);
        });

        // Handle new message
        socket.on('message:send', async (data) => {
            await handleSendMessage(socket, data);
        });

        // Handle message edit
        socket.on('message:edit', async (data) => {
            await handleEditMessage(socket, data);
        });

        // Handle message delete
        socket.on('message:delete', async (data) => {
            await handleDeleteMessage(socket, data);
        });

        // Handle typing indicator
        socket.on('typing:start', (groupId) => {
            handleTypingStart(socket, groupId);
        });

        socket.on('typing:stop', (groupId) => {
            handleTypingStop(socket, groupId);
        });

        // Handle message read
        socket.on('message:read', async (data) => {
            await handleMessageRead(socket, data);
        });

        // Handle disconnect
        socket.on('disconnect', () => {
            console.log(`❌ User disconnected: ${socket.user.username} (${socket.id})`);
        });
    });

    return io;
}

async function handleJoinGroup(socket, groupId) {
    try {
        // Check if user is member
        const checkQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const result = await pool.query(checkQuery, [groupId, socket.user.id]);

        if (!result.rows[0].is_member) {
            socket.emit('error', { message: 'You are not a member of this group' });
            return;
        }

        socket.join(`group:${groupId}`);

        // Notify others in group
        socket.to(`group:${groupId}`).emit('user:joined', {
            userId: socket.user.id,
            username: socket.user.username
        });

        console.log(`📍 ${socket.user.username} joined group ${groupId}`);
    } catch (error) {
        console.error('Error joining group:', error);
        socket.emit('error', { message: 'Failed to join group' });
    }
}

function handleLeaveGroup(socket, groupId) {
    socket.leave(`group:${groupId}`);

    // Notify others in group
    socket.to(`group:${groupId}`).emit('user:left', {
        userId: socket.user.id,
        username: socket.user.username
    });

    console.log(`📍 ${socket.user.username} left group ${groupId}`);
}

async function handleSendMessage(socket, data) {
    const { groupId, content, messageType, mediaUrl, replyToId } = data;

    try {
        // Check if user is member
        const checkQuery = `
            SELECT EXISTS(
                SELECT 1 FROM group_members 
                WHERE group_id = $1 AND user_id = $2
            ) as is_member
        `;

        const checkResult = await pool.query(checkQuery, [groupId, socket.user.id]);

        if (!checkResult.rows[0].is_member) {
            socket.emit('error', { message: 'You are not a member of this group' });
            return;
        }

        // Save message to database
        const insertQuery = `
            INSERT INTO chat_messages (group_id, sender_id, message_type, content, media_url, reply_to_id)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `;

        const result = await pool.query(insertQuery, [
            groupId,
            socket.user.id,
            messageType || 'text',
            content,
            mediaUrl || null,
            replyToId || null
        ]);

        const message = result.rows[0];

        // Prepare message payload
        const messagePayload = {
            id: message.id,
            groupId: message.group_id,
            sender: {
                id: socket.user.id,
                username: socket.user.username,
                displayName: socket.user.display_name,
                avatarUrl: socket.user.avatar_url
            },
            messageType: message.message_type,
            content: message.content,
            mediaUrl: message.media_url,
            replyToId: message.reply_to_id,
            createdAt: message.created_at,
            isEdited: message.is_edited
        };

        // Emit to all users in the group
        io.to(`group:${groupId}`).emit('message:new', messagePayload);

        // Send confirmation to sender
        socket.emit('message:sent', {
            tempId: data.tempId, // Client-generated temp ID
            messageId: message.id
        });

        console.log(`💬 ${socket.user.username} sent message to group ${groupId}`);

        // ── Game Commands Integration ──────────────────────────────
        // Check for game commands (/truth, /dare, /sike)
        if (socket.user.id !== GEMINI_BOT_ID) {
            processGameCommand(groupId, content);
        }

        // ── Gemini AI Integration ──────────────────────────────
        // Don't process bot's own messages
        if (socket.user.id !== GEMINI_BOT_ID) {
            processGeminiResponse(groupId, socket.user.username, content);
        }

    } catch (error) {
        console.error('Error sending message:', error);
        socket.emit('error', { message: 'Failed to send message' });
    }
}

async function handleEditMessage(socket, data) {
    const { messageId, content } = data;

    try {
        // Check if user owns the message
        const checkQuery = `
            SELECT group_id FROM chat_messages 
            WHERE id = $1 AND sender_id = $2 AND is_deleted = false
        `;

        const checkResult = await pool.query(checkQuery, [messageId, socket.user.id]);

        if (checkResult.rows.length === 0) {
            socket.emit('error', { message: 'Message not found or unauthorized' });
            return;
        }

        const groupId = checkResult.rows[0].group_id;

        // Update message
        const updateQuery = `
            UPDATE chat_messages
            SET content = $2, is_edited = true, updated_at = NOW()
            WHERE id = $1
            RETURNING *
        `;

        const result = await pool.query(updateQuery, [messageId, content]);
        const message = result.rows[0];

        // Emit to group
        io.to(`group:${groupId}`).emit('message:edited', {
            messageId: message.id,
            content: message.content,
            isEdited: true,
            updatedAt: message.updated_at
        });

        console.log(`✏️ ${socket.user.username} edited message ${messageId}`);
    } catch (error) {
        console.error('Error editing message:', error);
        socket.emit('error', { message: 'Failed to edit message' });
    }
}

async function handleDeleteMessage(socket, data) {
    const { messageId } = data;

    try {
        // Check if user owns the message
        const checkQuery = `
            SELECT group_id FROM chat_messages 
            WHERE id = $1 AND sender_id = $2
        `;

        const checkResult = await pool.query(checkQuery, [messageId, socket.user.id]);

        if (checkResult.rows.length === 0) {
            socket.emit('error', { message: 'Message not found or unauthorized' });
            return;
        }

        const groupId = checkResult.rows[0].group_id;

        // Soft delete message
        const deleteQuery = `
            UPDATE chat_messages
            SET is_deleted = true, content = '[Message deleted]', updated_at = NOW()
            WHERE id = $1
        `;

        await pool.query(deleteQuery, [messageId]);

        // Emit to group
        io.to(`group:${groupId}`).emit('message:deleted', {
            messageId: messageId
        });

        console.log(`🗑️ ${socket.user.username} deleted message ${messageId}`);
    } catch (error) {
        console.error('Error deleting message:', error);
        socket.emit('error', { message: 'Failed to delete message' });
    }
}

function handleTypingStart(socket, groupId) {
    socket.to(`group:${groupId}`).emit('typing:user', {
        userId: socket.user.id,
        username: socket.user.username,
        isTyping: true
    });
}
function handleTypingStop(socket, groupId) {
    socket.to(`group:${groupId}`).emit('typing:user', {
        userId: socket.user.id,
        username: socket.user.username,
        isTyping: false
    });
}

async function handleMessageRead(socket, data) {
    const { messageId } = data;

    try {
        // Insert read receipt
        const query = `
            INSERT INTO message_read_receipts (message_id, user_id)
            VALUES ($1, $2)
            ON CONFLICT (message_id, user_id) DO NOTHING
            RETURNING *
        `;

        await pool.query(query, [messageId, socket.user.id]);

        // Get message's group
        const msgQuery = 'SELECT group_id, sender_id FROM chat_messages WHERE id = $1';
        const msgResult = await pool.query(msgQuery, [messageId]);

        if (msgResult.rows.length > 0) {
            const { group_id, sender_id } = msgResult.rows[0];

            // Notify message sender
            io.to(`user:${sender_id}`).emit('message:read', {
                messageId: messageId,
                readBy: {
                    id: socket.user.id,
                    username: socket.user.username
                }
            });
        }
    } catch (error) {
        console.error('Error marking message as read:', error);
    }
}

function getIO() {
    if (!io) {
        throw new Error('Socket.io not initialized');
    }
    return io;
}

/**
 * Helper to get random item from array
 */
function getRandom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

/**
 * Process game commands (/truth, /dare, /sike)
 * Runs async and posts game content to the group
 */
async function processGameCommand(groupId, content) {
    try {
        console.log(`🎮 Processing game command in group ${groupId}: "${content}"`);
        
        let gameResponse = null;
        let gameType = null;

        if (/^\/truth/i.test(content)) {
            gameType = 'truth';
            gameResponse = getRandom(truths);
            console.log(`🎭 Truth selected: ${gameResponse}`);
        } else if (/^\/dare/i.test(content)) {
            gameType = 'dare';
            gameResponse = getRandom(dares);
            console.log(`⚡ Dare selected: ${gameResponse}`);
        } else if (/^\/sike/i.test(content)) {
            gameType = 'sike';
            const questionData = getRandom(sikeQuestions);
            gameResponse = `🎯 ${questionData.question}\n\n📚 Category: ${questionData.category}\n\n(Answer: ${questionData.answer})`;
            console.log(`🎯 Sike question selected: ${questionData.question}`);
        }

        if (!gameResponse) {
            console.log(`❌ Not a recognized game command: "${content}"`);
            return; // Not a game command
        }

        // Add emoji prefix based on game type
        const emoji = gameType === 'truth' ? '🎭' : gameType === 'dare' ? '⚡' : '🎯';
        const botMsg = await saveBotMessage(groupId, `${emoji} **${gameType.toUpperCase()}**: ${gameResponse}`);
        
        if (!botMsg) {
            console.error(`❌ Failed to save bot message for game command: ${gameType}`);
            return;
        }

        const payload = buildBotPayload(botMsg);
        io.to(`group:${groupId}`).emit('message:new', payload);

        console.log(`✅ Game command processed successfully in group ${groupId}: ${gameType}`);
    } catch (error) {
        console.error('❌ Game command processing error:', error.message);
        console.error('Stack trace:', error.stack);
        // Silently fail — never break the chat
    }
}

async function processGeminiResponse(groupId, senderUsername, content) {
    try {
        const isMention = /@gemini/i.test(content);

        if (isMention) {
            // ── @gemini mention: always respond ──
            console.log(`🤖 Gemini mentioned by ${senderUsername} in group ${groupId}`);

            // Small delay so the bot feels natural, not instant
            await new Promise(r => setTimeout(r, 1000 + Math.random() * 1500));

            const reply = await handleMention(groupId, senderUsername, content);
            if (!reply) return;

            const botMsg = await saveBotMessage(groupId, reply);
            if (!botMsg) return;

            const payload = buildBotPayload(botMsg);
            io.to(`group:${groupId}`).emit('message:new', payload);

            console.log(`🤖 Gemini replied in group ${groupId}`);
        } else {
            // ── Passive roast check (runs with random chance gate inside) ──
            const roast = await checkForRoast(groupId, senderUsername, content);
            if (!roast) return;

            // Longer delay for roasts to feel organic
            await new Promise(r => setTimeout(r, 2000 + Math.random() * 3000));

            const botMsg = await saveBotMessage(groupId, roast);
            if (!botMsg) return;

            const payload = buildBotPayload(botMsg);
            io.to(`group:${groupId}`).emit('message:new', payload);

            console.log(`🔥 Gemini roasted ${senderUsername} in group ${groupId}`);
        }
    } catch (error) {
        console.error('Gemini processing error:', error.message);
        // Silently fail — never break the chat for AI features
    }
}

export { initializeSocket, getIO };