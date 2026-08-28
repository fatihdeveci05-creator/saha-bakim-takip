import { eq } from 'drizzle-orm'
import { useDb } from '../database/client'
import { users } from '../database/schema'

export async function getUserTeamId(userId: number): Promise<number | null> {
  const [row] = await useDb().select({ takimId: users.takimId }).from(users).where(eq(users.id, userId)).limit(1)
  return row?.takimId ?? null
}
