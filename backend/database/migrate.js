import fs from "fs";
import pkg from "pg";
import dotenv from "dotenv";

dotenv.config();

const { Client } = pkg;

const client = new Client({
    connectionString: process.env.DIRECT_URL,
    ssl: {
        rejectUnauthorized: false,
    },
});

async function migrate() {
    try {
        await client.connect();
        console.log("Connected to database");

        const sql = fs.readFileSync("./database/init.sql").toString();
        await client.query(sql);

        console.log("Migration successful!");
    } catch (err) {
        console.error("Migration failed:", err);
    } finally {
        await client.end();
    }
}

migrate();
