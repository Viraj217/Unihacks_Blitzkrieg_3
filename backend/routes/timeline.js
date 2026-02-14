import express from 'express';
import {
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
} from '../controllers/timelineController.js';
import { verifyUser } from '../middleware/verify.js';

const Trouter = express.Router();

// All routes require authentication
Trouter.use(verifyUser);

// Timeline events
Trouter.post('/', createEvent);
Trouter.get('/:id', getEventById);
Trouter.put('/:id', updateEvent);
Trouter.delete('/:id', deleteEvent);

// Event actions
Trouter.patch('/:id/pin', togglePin);

// Event media
Trouter.post('/:id/media', addMedia);
Trouter.delete('/:id/media/:mediaId', deleteMedia);

// Event comments
Trouter.post('/:id/comments', addComment);
Trouter.delete('/:id/comments/:commentId', deleteComment);

// Event reactions
Trouter.post('/:id/reactions', addReaction);
Trouter.delete('/:id/reactions', removeReaction);

export default Trouter;