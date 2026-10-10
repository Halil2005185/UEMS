import fs from "fs";
import path from "path";
import { pool } from "../config/database.js";

// `npm run db:init`  -> create the tables
// `npm run db:reset` -> drop everything first, then create the tables (deletes all data!)
const reset = process.argv.includes("--reset");
const files = reset ? ["sql/drop.sql", "sql/schema.sql"] : ["sql/schema.sql"];

try {
    for (const file of files) {
        const sql = fs.readFileSync(path.resolve(file), "utf8");
        await pool.query(sql);
        console.log(`✅ Ran ${file}`);
    }
} catch (error) {
    console.error("❌", (error as Error).message);
    process.exitCode = 1;
} finally {
    await pool.end();
}
