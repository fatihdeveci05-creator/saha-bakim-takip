export type Period = '' | 'bugun' | 'hafta' | 'ay' | 'ozel'

export const PERIOD_LABELS: Record<Period, string> = {
  '': 'Tüm Zamanlar',
  bugun: 'Bugün',
  hafta: 'Bu Hafta',
  ay: 'Bu Ay',
  ozel: 'Tarih Aralığı Seç',
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

/** "YYYY-MM-DD" (input[type=date] değeri) → günün başlangıcı/sonu ISO string'i. */
export function dateInputToIsoStart(value: string) {
  return value ? new Date(`${value}T00:00:00`).toISOString() : undefined
}

export function dateInputToIsoEnd(value: string) {
  return value ? new Date(`${value}T23:59:59.999`).toISOString() : undefined
}

export function periodQueryString(period: Period, customFrom = '', customTo = '') {
  const params = new URLSearchParams()
  if (period === 'ozel') {
    const from = dateInputToIsoStart(customFrom)
    const to = dateInputToIsoEnd(customTo)
    if (from) params.set('from', from)
    if (to) params.set('to', to)
  } else {
    const { from, to } = periodRange(period)
    if (from) params.set('from', from)
    if (to) params.set('to', to)
  }
  return params.toString()
}
