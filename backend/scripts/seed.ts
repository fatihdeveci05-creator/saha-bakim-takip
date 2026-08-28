import { drizzle } from 'drizzle-orm/mysql2'
import { eq } from 'drizzle-orm'
import mysql from 'mysql2/promise'
import bcrypt from 'bcryptjs'
import * as schema from '../server/database/schema'

async function main() {
  const pool = mysql.createPool({ uri: process.env.DATABASE_URL })
  const db = drizzle(pool, { schema, mode: 'default' })

  const email = 'admin@abbkontrol.local'
  const [existing] = await db
    .select({ id: schema.users.id })
    .from(schema.users)
    .where(eq(schema.users.email, email))
    .limit(1)

  if (existing) {
    console.log(`Zaten mevcut: ${email}`)
    await pool.end()
    return
  }

  const passwordHash = await bcrypt.hash('Admin123!', 12)
  await db.insert(schema.users).values({
    ad: 'Sistem Yöneticisi',
    email,
    passwordHash,
    taraf: 'isveren',
    rol: 'yonetici',
    aktif: true,
  })

  console.log(`İlk yönetici kullanıcı oluşturuldu: ${email} / Admin123!`)
  await pool.end()
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
