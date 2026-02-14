import express from 'express';
import multer from 'multer';
import { createPost, getPosts, upload } from '../controllers/postController.js';
import { verifyUser } from '../middleware/verify.js';

const router = express.Router();

// Define routes
router.post('/timeline/posts', verifyUser, upload.single('image'), createPost);
router.get('/timeline/posts', verifyUser, getPosts);

export default router;
