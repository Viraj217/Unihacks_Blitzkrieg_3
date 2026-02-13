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
import { verifyUser } from '../middleware/verify.js';

const Caprouter = express.Router();

// All routes require authentication
Caprouter.use(verifyUser);

// Capsule CRUD
Caprouter.post('/', createCapsule);
Caprouter.get('/:id', getCapsuleById);
Caprouter.put('/:id', updateCapsule);
Caprouter.delete('/:id', deleteCapsule);

// Capsule actions
Caprouter.post('/:id/unlock', unlockCapsule);

// Capsule contents
Caprouter.post('/:id/contents', addContent);
Caprouter.delete('/:id/contents/:contentId', deleteContent);

// Capsule reactions
Caprouter.post('/:id/reactions', addReaction);
Caprouter.delete('/:id/reactions', removeReaction);

export default Caprouter;