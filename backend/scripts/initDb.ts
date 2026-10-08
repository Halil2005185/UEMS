// import fs from "fs";
// import path from "path";
// import { pool } from "../config/database.js";

// const sql = fs.readFileSync(path.resolve("sql/schema.sql"), "utf8");

// try {
//     await pool.query(sql);
//     console.log("✅ Tables created");
// } catch (error) {
//     console.error("❌", (error as Error).message);
// } finally {
//     await pool.end();
// }
