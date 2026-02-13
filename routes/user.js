import express from "express";
const app = express()
const router = express.Router()
import { createProfile, getProfileByid } from "../controllers/userControllers.js";

router.get("/user/get", getProfileByid);
router.post("/user/profile/create", createProfile);

export default router;