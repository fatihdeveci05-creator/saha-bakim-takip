import { drizzle } from 'drizzle-orm/mysql2'
import mysql from 'mysql2/promise'
import * as schema from './schema'

function createDb() {
  const pool = mysql.createPool({
    uri: useRuntimeConfig().databaseUrl,
    connectionLimit: 10,
  })
  return drizzle(pool, { schema, mode: 'default' })
}

let _db: ReturnType<typeof createDb> | undefined

export function useDb() {
  if (!_db) {
    _db = createDb()
  }
  return _db
}
