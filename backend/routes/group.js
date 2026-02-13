import express from "express";
const app = express()
const Grouter = express.Router()

import { createGroup, getGroupById, updateGroup, deleteGroup, joinGroup, leaveGroup, getGroupMembers, removeMember, createJoinRequest, getJoinRequests, respondToJoinRequest } from "../controllers/groupController.js";
import { verifyUser } from "../middleware/verify.js";

Grouter.post("/group/create", verifyUser, createGroup);
Grouter.get("/group/:id", verifyUser, getGroupById);
Grouter.put("/group/:id", verifyUser, updateGroup);
Grouter.delete("/group/:id", verifyUser, deleteGroup);
Grouter.post("/group/:id/join", verifyUser, joinGroup);
Grouter.post("/group/:id/leave", verifyUser, leaveGroup);
Grouter.get("/group/:id/members", verifyUser, getGroupMembers);
Grouter.post("/group/:id/members/remove", verifyUser, removeMember);
Grouter.post("/group/:id/join-request", verifyUser, createJoinRequest);
Grouter.get("/group/:id/join-requests", verifyUser, getJoinRequests);
Grouter.post("/group/:id/join-requests/:requestId/respond", verifyUser, respondToJoinRequest);

export default Grouter;