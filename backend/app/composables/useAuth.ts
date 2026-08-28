export interface AuthUser {
  id: number
  ad: string
  email: string
  taraf: 'isveren' | 'alt_yuklenici'
  rol: string
}

const TOKEN_KEY = 'abb_access_token'
const REFRESH_KEY = 'abb_refresh_token'

export function useAuth() {
  const user = useState<AuthUser | null>('auth_user', () => null)
  const accessToken = useState<string | null>('auth_access_token', () => null)
  const refreshToken = useState<string | null>('auth_refresh_token', () => null)
  const ready = useState('auth_ready', () => false)

  function persist() {
    if (accessToken.value) localStorage.setItem(TOKEN_KEY, accessToken.value)
    else localStorage.removeItem(TOKEN_KEY)
    if (refreshToken.value) localStorage.setItem(REFRESH_KEY, refreshToken.value)
    else localStorage.removeItem(REFRESH_KEY)
  }

  function clear() {
    user.value = null
    accessToken.value = null
    refreshToken.value = null
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(REFRESH_KEY)
  }

  async function fetchMe() {
    user.value = await $fetch<AuthUser>('/api/auth/me', {
      headers: { Authorization: `Bearer ${accessToken.value}` },
    })
  }

  async function tryRefresh() {
    if (!refreshToken.value) {
      clear()
      return false
    }
    try {
      const res = await $fetch<{ accessToken: string }>('/api/auth/refresh', {
        method: 'POST',
        body: { refreshToken: refreshToken.value },
      })
      accessToken.value = res.accessToken
      persist()
      await fetchMe()
      return true
    } catch {
      clear()
      return false
    }
  }

  async function init() {
    if (ready.value) return
    accessToken.value = localStorage.getItem(TOKEN_KEY)
    refreshToken.value = localStorage.getItem(REFRESH_KEY)
    if (accessToken.value) {
      try {
        await fetchMe()
      } catch {
        await tryRefresh()
      }
    }
    ready.value = true
  }

  async function login(email: string, password: string) {
    const res = await $fetch<{ accessToken: string; refreshToken: string; user: AuthUser }>('/api/auth/login', {
      method: 'POST',
      body: { email, password },
    })
    accessToken.value = res.accessToken
    refreshToken.value = res.refreshToken
    user.value = res.user
    persist()
  }

  function logout() {
    clear()
    navigateTo('/login')
  }

  return { user, accessToken, refreshToken, ready, init, login, logout, tryRefresh }
}
