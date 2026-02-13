import express from 'express';
import {
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
} from '../controllers/capsuleController.js';
import { verifyToken } from '../middleware/verify.js';

const Crouter = express.Router();

// All routes require authentication
Crouter.use(verifyToken);

// Capsule CRUD
Crouter.post('/', createCapsule);
Crouter.get('/:id', getCapsuleById);
Crouter.put('/:id', updateCapsule);
Crouter.delete('/:id', deleteCapsule);

// Capsule actions
Crouter.post('/:id/unlock', unlockCapsule);

// Capsule contents
Crouter.post('/:id/contents', addContent);
Crouter.delete('/:id/contents/:contentId', deleteContent);

// Capsule reactions
Crouter.post('/:id/reactions', addReaction);
Crouter.delete('/:id/reactions', removeReaction);

export default Crouter;