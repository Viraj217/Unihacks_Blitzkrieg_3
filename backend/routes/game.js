import express from 'express';
import {
    getTruthOrDare,
    startPoll,
    castVote,
    getPollResults
} from '../controllers/GameController.js';

const router = express.Router();

// Truth or Dare Endpoint
// POST /api/games/tod -> Body: { "type": "truth" }
router.post('/tod', getTruthOrDare);

// Most Likely To Endpoints
// POST /api/games/poll/start -> Starts new round
router.post('/poll/start', startPoll);

// POST /api/games/poll/vote -> Body: { "voter": "Alice", "candidate": "Bob" }
router.post('/poll/vote', castVote);

// GET /api/games/poll/result -> Ends round and shows winner
router.get('/poll/result', getPollResults);

export default router;