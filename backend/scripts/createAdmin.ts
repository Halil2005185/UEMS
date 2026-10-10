import { pool } from "../config/database.js";

import { hashPassword } from "../utils/password.js";

const hashedPassword = await hashPassword("admin123");

try {
  // ON CONFLICT: running the script twice does not fail on the same email
  const result = await pool.query(
    `INSERT INTO users (name, email, password_hash, role)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO NOTHING
     RETURNING id, name, email, role`,
    ["System Admin", "admin@uni.edu", hashedPassword, "ADMIN"]
  );

  if (result.rows.length > 0) {
    console.log("✅ Created:", result.rows[0]);
  } else {
    console.log("ℹ️ Admin already exists, nothing changed");
  }
} catch (error) {
  console.error("❌", (error as Error).message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
