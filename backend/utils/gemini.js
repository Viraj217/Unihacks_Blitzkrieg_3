import { GoogleGenerativeAI } from '@google/generative-ai';
import dotenv from 'dotenv';
import pool from '../database/pool.js';

dotenv.config();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const GEMINI_BOT_ID = '00000000-0000-0000-0000-000000000001'; // Fixed UUID for the bot

const SYSTEM_PROMPT = `You are "Gemini", the savage AI assistant living inside a group chat app called Beme.

Your personality:
- You are witty, sarcastic, and love roasting people (but never cross into being genuinely hurtful or offensive)
- You give helpful answers when asked questions, but always with a bit of personality
- Your roasts are clever and funny, never mean-spirited — think comedy roast, not bullying
- Keep responses SHORT (1-3 sentences max). This is a chat, not an essay
- Use emojis sparingly but effectively 🔥
- You speak like a Gen-Z friend who happens to be incredibly smart
- If someone asks for help, help them — but maybe throw in a light jab
- When roasting, be creative and specific to what they said

Rules:
- NEVER be racist, sexist, homophobic, or genuinely cruel
- Keep it PG-13 — edgy humor is fine, vulgarity is not
- If someone seems upset, drop the roast persona and be supportive
- Always respond in the same language the user is writing in`;

const ROAST_CHECK_PROMPT = `You are monitoring a group chat. Your job is to decide if a message deserves a witty roast/reaction.

Roast-worthy messages include:
- Cringe or over-the-top statements
- Humble-brags or obvious flex attempts
- Terrible jokes or puns
- Overly dramatic messages about mundane things
- Someone saying something obviously wrong with confidence
- Auto-correct fails or funny typos
- Messages where someone is setting themselves up

NOT roast-worthy:
- Normal conversation
- Serious topics (health, family, relationships, grief)
- Simple greetings or short messages
- Messages that are already funny on their own
- Questions asking for real help

Respond with ONLY a JSON object:
{"shouldRoast": true/false, "roast": "your roast here if shouldRoast is true, otherwise empty string"}

Keep roasts to 1-2 sentences max. Be clever, not mean.`;

/**
 * Ensure the Gemini bot profile exists in the database.
 * Creates it if it doesn't exist.
 */
async function ensureBotProfile() {
    try {
        const checkQuery = `SELECT id FROM profiles WHERE id = $1`;
        const result = await pool.query(checkQuery, [GEMINI_BOT_ID]);

        if (result.rows.length === 0) {
            // auth_id and email are NOT NULL in schema, so we provide dummy values
            const BOT_AUTH_ID = '00000000-0000-0000-0000-000000000002';

            const insertQuery = `
                INSERT INTO profiles (id, auth_id, username, email, display_name, avatar_url)
                VALUES ($1, $2, 'gemini', 'gemini@bot.com', 'Gemini AI ✨', NULL)
                ON CONFLICT (id) DO NOTHING
            `;

            // If auth_id or email constraint fails (e.g. already taken), we log it
            await pool.query(insertQuery, [GEMINI_BOT_ID, BOT_AUTH_ID]);
            console.log('🤖 Gemini bot profile created');
        }
    } catch (error) {
        console.error('Error ensuring bot profile:', error.message);
    }
}

/**
 * Get recent messages from a group for context
 */
async function getRecentMessages(groupId, limit = 15) {
    try {
        const query = `
            SELECT cm.content, cm.sender_id, p.username
            FROM chat_messages cm
            LEFT JOIN profiles p ON cm.sender_id = p.id
            WHERE cm.group_id = $1 AND cm.is_deleted = false
            ORDER BY cm.created_at DESC
            LIMIT $2
        `;
        const result = await pool.query(query, [groupId, limit]);
        return result.rows.reverse(); // chronological order
    } catch (error) {
        console.error('Error fetching recent messages:', error.message);
        return [];
    }
}

/**
 * Send a message to Gemini and get a response (for @gemini mentions)
 */
async function handleMention(groupId, senderUsername, messageContent) {
    try {
        const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

        // Get recent chat context
        const recentMessages = await getRecentMessages(groupId);
        const chatContext = recentMessages
            .map(m => `${m.username || 'Unknown'}: ${m.content}`)
            .join('\n');

        // Remove @gemini from the prompt
        const userPrompt = messageContent.replace(/@gemini/gi, '').trim();

        const prompt = `${SYSTEM_PROMPT}

Here's the recent chat history for context:
---
${chatContext}
---

${senderUsername} just tagged you and said: "${userPrompt}"

Respond naturally as part of the chat:`;

        const result = await model.generateContent(prompt);
        const response = result.response.text();

        return response;
    } catch (error) {
        console.error('Gemini mention error:', error.message);
        return "Bro my brain just glitched 💀 try again";
    }
}

/**
 * Check if a message is roast-worthy and generate a roast
 * Returns null if not worth roasting
 */
async function checkForRoast(groupId, senderUsername, messageContent) {
    try {
        // Don't roast bot messages or very short messages
        if (messageContent.length < 10) return null;

        // Random chance gate — only check ~25% of messages to avoid spam
        if (Math.random() > 0.25) return null;

        const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

        const prompt = `${ROAST_CHECK_PROMPT}

The message from "${senderUsername}": "${messageContent}"

Respond with ONLY valid JSON:`;

        const result = await model.generateContent(prompt);
        const responseText = result.response.text().trim();

        // Parse the JSON response
        // Handle potential markdown code blocks in response
        const cleanJson = responseText
            .replace(/```json\n?/g, '')
            .replace(/```\n?/g, '')
            .trim();

        const parsed = JSON.parse(cleanJson);

        if (parsed.shouldRoast && parsed.roast) {
            return parsed.roast;
        }

        return null;
    } catch (error) {
        // Silently fail — roasting is optional
        console.error('Roast check error:', error.message);
        return null;
    }
}

/**
 * Save a bot message to the database and return the full message object
 */
async function saveBotMessage(groupId, content) {
    try {
        const insertQuery = `
            INSERT INTO chat_messages (group_id, sender_id, message_type, content)
            VALUES ($1, $2, 'text', $3)
            RETURNING *
        `;

        const result = await pool.query(insertQuery, [groupId, GEMINI_BOT_ID, content]);
        return result.rows[0];
    } catch (error) {
        console.error('Error saving bot message:', error.message);
        return null;
    }
}

/**
 * Build the message payload matching the socket format
 */
function buildBotPayload(message) {
    return {
        id: message.id,
        groupId: message.group_id,
        sender: {
            id: GEMINI_BOT_ID,
            username: 'gemini',
            displayName: 'Gemini AI ✨',
            avatarUrl: null,
        },
        messageType: 'text',
        content: message.content,
        mediaUrl: null,
        replyToId: null,
        createdAt: message.created_at,
        isEdited: false,
        isBot: true,  // Extra flag for frontend styling
    };
}

export {
    ensureBotProfile,
    handleMention,
    checkForRoast,
    saveBotMessage,
    buildBotPayload,
    GEMINI_BOT_ID,
};
