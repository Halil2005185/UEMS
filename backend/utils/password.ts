import bcrypt from "bcrypt"

const SALT_ROUNDS = 10


// used when creating a new user
export async function hashPassword(password : string){
    return await bcrypt.hash(password , SALT_ROUNDS)
}

// used when comparing the password during login
export async function verifyPassword(password: string , hashedPassword : string){
    return await bcrypt.compare(password , hashedPassword)
}