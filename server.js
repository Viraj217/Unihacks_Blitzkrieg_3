import express from "express";
import dotenv from "dotenv";
import supabase from "./config/supabasedb.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;




app.post("/user/profile", (req, res) => {
    res.send("Hello World!");
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
}); 