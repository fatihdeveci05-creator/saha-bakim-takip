export type Period = '' | 'bugun' | 'hafta' | 'ay'

export const PERIOD_LABELS: Record<Period, string> = {
  '': 'Tüm Zamanlar',
  bugun: 'Bugün',
  hafta: 'Bu Hafta',
  ay: 'Bu Ay',
}

/** Seçilen döneme karşılık gelen { from, to } ISO aralığını döner (period='' ise ikisi de undefined). */
export function periodRange(period: Period): { from?: string; to?: string } {
  const now = new Date()
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  if (period === 'bugun') {
    return { from: startOfDay.toISOString() }
  }
  if (period === 'hafta') {
    const dayIndex = (now.getDay() + 6) % 7 // Pazartesi = 0
    const monday = new Date(startOfDay)
    monday.setDate(monday.getDate() - dayIndex)
    return { from: monday.toISOString() }
  }
  if (period === 'ay') {
    const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
    return { from: firstOfMonth.toISOString() }
  }
  return {}
}

export function periodQueryString(period: Period) {
  const { from, to } = periodRange(period)
  const params = new URLSearchParams()
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  return params.toString()
}
