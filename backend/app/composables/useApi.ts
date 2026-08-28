export function useApi() {
  const auth = useAuth()

  async function apiFetch<T>(url: string, opts: Record<string, unknown> = {}): Promise<T> {
    const headers = {
      ...(opts.headers as Record<string, string> | undefined),
      Authorization: auth.accessToken.value ? `Bearer ${auth.accessToken.value}` : '',
    }
    try {
      return (await $fetch(url, { ...opts, headers })) as T
    } catch (err) {
      const statusCode = (err as { statusCode?: number })?.statusCode
      if (statusCode === 401) {
        const ok = await auth.tryRefresh()
        if (ok) {
          const headers2 = { ...headers, Authorization: `Bearer ${auth.accessToken.value}` }
          return (await $fetch(url, { ...opts, headers: headers2 })) as T
        }
        await navigateTo('/login')
      }
      throw err
    }
  }

  return { apiFetch }
}
