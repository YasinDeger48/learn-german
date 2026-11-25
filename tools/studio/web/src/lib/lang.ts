import { useEffect, useState } from 'react'

/** The second column next to Türkçe on the content pages: English or one of the other learner languages. */
export const SECOND_LANGS = [
  ['en', 'English'],
  ['es', 'Español'],
  ['fr', 'Français'],
  ['it', 'Italiano'],
  ['ku', 'Kurmancî'],
  ['ar', 'العربية'],
] as const
export type SecondLang = (typeof SECOND_LANGS)[number][0]

const KEY = 'studio.secondLang'
const EVENT = 'studio-second-lang'

function read(): SecondLang {
  try {
    const value = localStorage.getItem(KEY)
    if (SECOND_LANGS.some(([code]) => code === value)) return value as SecondLang
  } catch { /* storage blocked: default */ }
  return 'en'
}

/** The chosen second language, shared by every page (kept in this browser). */
export function useSecondLang(): [SecondLang, (lang: SecondLang) => void] {
  const [lang, setLang] = useState<SecondLang>(read)
  useEffect(() => {
    const changed = () => setLang(read())
    window.addEventListener(EVENT, changed)
    return () => window.removeEventListener(EVENT, changed)
  }, [])
  const choose = (next: SecondLang) => {
    try { localStorage.setItem(KEY, next) } catch { /* not kept */ }
    setLang(next)
    window.dispatchEvent(new Event(EVENT))
  }
  return [lang, choose]
}

export const langName = (code: string) => SECOND_LANGS.find(([c]) => c === code)?.[1] ?? code
export const langDir = (code: string): 'rtl' | undefined => (code === 'ar' ? 'rtl' : undefined)

/** A text in one language from a {tr, en, es, …} object ('' when it is not translated yet). */
export const inLang = (values: Record<string, string | undefined> | undefined, code: string) => values?.[code] ?? ''
