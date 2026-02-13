import express from "express";
const app = express()
const router = express.Router()
import { createProfile, getProfileByid, updateProfile, deleteProfile } from "../controllers/userControllers.js";
import { verifyUser } from "../middleware/verify.js";
router.get("/user/get", verifyUser, getProfileByid);
router.post("/user/profile/create", verifyUser, createProfile);
router.put("/user/profile/update", verifyUser, updateProfile);
router.delete("/user/profile/delete", verifyUser, deleteProfile);

export default router;