export default defineNuxtRouteMiddleware(async (to) => {
  const auth = useAuth()
  if (!auth.ready.value) {
    await auth.init()
  }

  const isLoggedIn = !!auth.user.value
  const isIsveren = auth.user.value?.taraf === 'isveren'

  if (to.path === '/login') {
    if (isLoggedIn && isIsveren) return navigateTo('/')
    return
  }

  if (!isLoggedIn || !isIsveren) {
    return navigateTo('/login')
  }
})
