import { drizzle } from 'drizzle-orm/mysql2'
import mysql from 'mysql2/promise'
import * as schema from './schema'

function createDb() {
  const pool = mysql.createPool({
    uri: useRuntimeConfig().databaseUrl,
    connectionLimit: 10,
    // Raporlar gibi birden fazla paralel sorgu atan endpoint'ler ara sıra
    // "Connection lost" ile 500 dönüyordu — bağlantı SSH tüneli/ağ üzerinden
    // uzun süre boşta kalınca sessizce kesiliyor. TCP keepalive bunu önler.
    enableKeepAlive: true,
    keepAliveInitialDelay: 10_000,
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
