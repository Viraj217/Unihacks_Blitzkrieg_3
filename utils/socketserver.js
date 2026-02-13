import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import pool from '../database/pool.js';

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

            // Verify JWT token
            const decoded = jwt.verify(token, process.env.JWT_SECRET);

            // Get user from database
            const userQuery = 'SELECT id, username, display_name, avatar_url FROM profiles WHERE id = $1';
            const result = await pool.query(userQuery, [decoded.userId]);

            if (result.rows.length === 0) {
                return next(new Error('Authentication error: User not found'));
            }

            socket.user = result.rows[0];
            next();
        } catch (error) {
            next(new Error('Authentication error: Invalid token'));
        }
    });

    // Connection handler
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

