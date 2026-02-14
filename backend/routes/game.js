// backend/routes/game.js
import express from 'express';
import { getTruthOrDare, getSikeQuestion } from '../controllers/GameController.js';

const router = express.Router();

// POST request so you can send { "type": "truth" } in the body
router.post('/tod', getTruthOrDare);

// GET request is fine since no input is needed
router.get('/sike', getSikeQuestion);

export default router;