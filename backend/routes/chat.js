import express from 'express';
import { getChatHistory, getUnreadCount } from '../controllers/ChatControllers.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.use(authenticate);

router.get('/:groupId/messages', getChatHistory);
router.get('/unread', getUnreadCount);

export default router;