export const TIME_ZONE_ALIASES = {
  "Asia/Beijing": "Asia/Shanghai",
  "Asia/Calcutta": "Asia/Kolkata",
  "Asia/Chongqing": "Asia/Shanghai",
  "Asia/Katmandu": "Asia/Kathmandu",
  "Asia/Rangoon": "Asia/Yangon",
  "Asia/Saigon": "Asia/Ho_Chi_Minh",
  "Asia/Tel_Aviv": "Asia/Jerusalem",
  "Asia/Thimbu": "Asia/Thimphu",
  "Asia/Ulan_Bator": "Asia/Ulaanbaatar",
  "Europe/Kiev": "Europe/Kyiv",
  "America/Buenos_Aires": "America/Argentina/Buenos_Aires",
  "America/Catamarca": "America/Argentina/Catamarca",
  "America/Cordoba": "America/Argentina/Cordoba",
  "America/Godthab": "America/Nuuk",
  "America/Jujuy": "America/Argentina/Jujuy",
  "America/Mendoza": "America/Argentina/Mendoza",
  "Pacific/Ponape": "Pacific/Pohnpei",
}

export function normalizeTimeZone(timeZone) {
  return TIME_ZONE_ALIASES[timeZone] || timeZone
}