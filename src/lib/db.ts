import { Pool } from "pg";
import { drizzle } from "drizzle-orm/node-postgres";
import { users } from "@/db/schema";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL!,
});

const db = drizzle(pool);

export async function getUsers() {
  return db.select().from(users).orderBy(users.createdAt);
}

export async function createUserRecord(user: { email: string; name: string }) {
  return db.insert(users).values(user);
}
