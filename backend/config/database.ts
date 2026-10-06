import pg from "pg";

const { Pool } = pg;

export const pool = new Pool({
  host: "localhost",
  port: 5432,
  database: "UEMS_backend",
  user: "postgres",
  password: "Halil@2005",
});


pool.connect()
  .then(() => {
    console.log("✅ PostgreSQL connected");
  })
  .catch((error) => {
    console.error("❌ PostgreSQL connection failed:", error);
  });