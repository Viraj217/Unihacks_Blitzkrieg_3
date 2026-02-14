// backend/controllers/GameController.js
import { truths, dares, sikeQuestions } from '../utils/gameData.js';

// Helper to get random item
const getRandom = (arr) => arr[Math.floor(Math.random() * arr.length)];

// Truth or Dare Logic
async function getTruthOrDare(req, res) {
    try {
        const { type } = req.body; // Expecting { "type": "truth" } or { "type": "dare" }

        let content;
        if (type === 'truth') {
            content = getRandom(truths);
        } else if (type === 'dare') {
            content = getRandom(dares);
        } else {
            return res.status(400).json({ success: false, message: "Invalid type. Use 'truth' or 'dare'." });
        }

        res.status(200).send({
            success: true,
            data: {
                type: type,
                content: content
            }
        });

    } catch (error) {
        console.error("Game Controller Error:", error);
        res.status(500).json({ success: false, error: "Server error" });
    }
}

// Sike (Trivia) Logic
async function getSikeQuestion(req, res) {
    try {
        const questionData = getRandom(sikeQuestions);

        res.status(200).send({
            success: true,
            data: questionData
        });

    } catch (error) {
        console.error("Sike Controller Error:", error);
        res.status(500).json({ success: false, error: "Server error" });
    }
}

export {
    getTruthOrDare,
    getSikeQuestion
};