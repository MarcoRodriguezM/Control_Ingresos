export function isTrainingValidityExpired(value, today = new Date()) {
  const expiration = parseTrainingValidity(value)
  if (!expiration) return false

  const currentDay = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  return expiration < currentDay
}

function parseTrainingValidity(value) {
  const text = String(value ?? '').trim()
  if (!text) return null

  const iso = text.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?=\D|$)/)
  if (iso) return createDate(Number(iso[1]), Number(iso[2]), Number(iso[3]))

  const numeric = text.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?=\D|$)/)
  if (!numeric) return null

  const first = Number(numeric[1])
  const second = Number(numeric[2])
  const year = Number(numeric[3])
  // Dates converted from SQL DateTime use invariant month/day/year with a time;
  // date-only values use the local day/month/year order.
  const monthFirst = /\d{1,2}:\d{2}/.test(text) || (second > 12 && first <= 12)
  return monthFirst
    ? createDate(year, first, second)
    : createDate(year, second, first)
}

function createDate(year, month, day) {
  const date = new Date(year, month - 1, day)
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
    ? date
    : null
}
