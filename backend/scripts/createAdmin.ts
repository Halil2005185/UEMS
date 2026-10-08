import {pool} from "../config/database.js";

import { hashPassword , verifyPassword } from "../utils/password.js";

const hashedPassword = await hashPassword("admin123");

console.log(`Hash : ${hashedPassword}`)


const result = await pool.query(
  `INSERT INTO users (name, email, password_hash, role)
   VALUES ($1, $2, $3, $4)
   RETURNING id, name, email, role`,
  ["Selin Koç", "admin2@uni.edu", hashedPassword, "ADMIN"]
);

console.log("✅ Created:", result.rows[0]);

console.log("Correct password?", await verifyPassword("admin123", hashedPassword)); // true
console.log("Wrong password?  ", await verifyPassword("wrong", hashedPassword));    // false

await pool.end();