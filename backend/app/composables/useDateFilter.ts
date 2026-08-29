import type { Period } from '~/utils/dateRange'
import { periodQueryString } from '~/utils/dateRange'

/**
 * Dönem filtresini (Bugün/Bu Hafta/Bu Ay/Özel Tarih Aralığı) URL query'sinde
 * tutar — sayfadan çıkıp geri dönünce veya yenilenince filtre korunur.
 */
export function useDateFilter(defaultPeriod: Period = '') {
  const route = useRoute()
  const router = useRouter()

  const period = ref<Period>((route.query.period as Period) || defaultPeriod)
  const customFrom = ref((route.query.from as string) || '')
  const customTo = ref((route.query.to as string) || '')

  watch([period, customFrom, customTo], () => {
    const query = { ...route.query }
    if (period.value) query.period = period.value
    else delete query.period

    if (period.value === 'ozel' && customFrom.value) query.from = customFrom.value
    else delete query.from

    if (period.value === 'ozel' && customTo.value) query.to = customTo.value
    else delete query.to

    router.replace({ query })
  })

  const queryString = computed(() => periodQueryString(period.value, customFrom.value, customTo.value))

  return { period, customFrom, customTo, queryString }
}
