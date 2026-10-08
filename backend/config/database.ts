import pg from "pg";
import  "dotenv/config.js";
const { Pool } = pg;

export const pool = new Pool({
  host: process.env.PGHOST,
  port : Number(process.env.PGPORT) ,
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
});

try {
  await pool.query("SELECT 1");
  console.log("✅ PostgreSQL connected");
} catch (error) {
  console.error("❌ PostgreSQL connection failed:", (error as Error).message);
}