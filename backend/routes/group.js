import express from "express";
const app = express()
const Grouter = express.Router()

import { createGroup, getGroupById, updateGroup, deleteGroup } from "../controllers/groupController.js";
import { verifyUser } from "../middleware/verify.js";

Grouter.post("/group/create", verifyUser, createGroup);
Grouter.get("/group/:id", verifyUser, getGroupById);
Grouter.put("/group/:id", verifyUser, updateGroup);
Grouter.delete("/group/:id", verifyUser, deleteGroup);

export default Grouter;