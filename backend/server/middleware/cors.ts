// Native mobil istemcilerin CORS derdi yok; bu sadece Flutter web/desktop hedefiyle
// yerelde test ederken tarayıcının API'ye erişebilmesi içindir.
export default defineEventHandler((event) => {
  if (!event.path.startsWith('/api/') && !event.path.startsWith('/uploads/')) return

  setResponseHeaders(event, {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  })

  if (event.method === 'OPTIONS') {
    event.node.res.statusCode = 204
    event.node.res.end()
  }
})
