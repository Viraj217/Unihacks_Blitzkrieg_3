import express from "express";
import dotenv from "dotenv";
import router from "./routes/user.js";
import Arouter from "./routes/Auth.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());


app.listen(PORT, () => {
    console.log(`the server is listenning on port ${PORT}`);
});

app.use("/", router);
app.use("/", Arouter); 