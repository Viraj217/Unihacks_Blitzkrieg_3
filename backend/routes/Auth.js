import express from "express";
const app = express()
const Arouter = express.Router()

import { UserSignup, UserLogin } from "../controllers/AuthController.js";

Arouter.post("/user/login", UserLogin);
Arouter.post("/user/signup", UserSignup);

export default Arouter;