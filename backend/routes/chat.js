import express from 'express';
import { getChatHistory, getUnreadCount } from '../controllers/ChatController.js';
import { verifyUser } from '../middleware/verify.js';

const Crouter = express.Router();

Crouter.use(verifyUser);

Crouter.get('/:groupId/messages', getChatHistory);
Crouter.get('/unread', getUnreadCount);

export default Crouter;