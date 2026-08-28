// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  ssr: false,
  css: ['~/assets/css/main.css', 'leaflet/dist/leaflet.css'],
  // /api/* CORS'u server/middleware/cors.ts hallediyor; statik /uploads/* dosyaları
  // Nuxt dev'de o middleware zincirinden geçmiyor, bu yüzden ayrı bir routeRule gerekiyor
  // (Flutter web/desktop hedefiyle yerelde test ederken gerekli, native derlemede önemsiz).
  routeRules: {
    '/uploads/**': {
      headers: { 'Access-Control-Allow-Origin': '*' },
    },
  },
  runtimeConfig: {
    databaseUrl: process.env.DATABASE_URL,
    jwtSecret: process.env.JWT_SECRET,
  },
})
