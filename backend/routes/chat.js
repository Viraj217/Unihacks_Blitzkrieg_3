import express from 'express';
import { getChatHistory, getUnreadCount } from '../controllers/ChatControllers.js';
import { authenticate } from '../middleware/auth.js';

const Crouter = express.Router();

Crouter.use(authenticate);

Crouter.get('/:groupId/messages', getChatHistory);
Crouter.get('/unread', getUnreadCount);

export default Crouter;