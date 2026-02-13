import express from "express";
import dotenv from "dotenv";
import router from "./routes/user.js";
import Crouter from "./routes/chat.js";
import Arouter from "./routes/Auth.js";
import { createServer } from 'http';
import cors from 'cors';
import { initializeSocket } from './utils/socketserver.js';

dotenv.config();


const app = express();
const PORT = process.env.PORT || 3000;


const httpServer = createServer(app);

// Initialize Socket.io
const io = initializeSocket(httpServer);

// Middleware
app.use(cors({
    origin: process.env.CORS_ORIGIN?.split(',') || '*',
    credentials: true
}));
app.use(express.json())
app.use(express.urlencoded({ extended: true }));
app.use(express.json());



httpServer.listen(PORT, () => {
    console.log(`the server is listening on port ${PORT}`);
});

app.use("/", router);
app.use("/", Arouter);
app.use("/", Crouter);