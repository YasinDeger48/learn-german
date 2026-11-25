import { Languages } from 'lucide-react'
import { SECOND_LANGS, useSecondLang, type SecondLang } from '@/lib/lang'

/** Sidebar control: which language the content pages show next to Türkçe. */
export function LangPicker() {
  const [lang, setLang] = useSecondLang()
  return (
    <label className="flex items-center gap-2 px-2.5 pt-3 text-xs text-nav-muted">
      <Languages className="size-4 shrink-0 opacity-80" aria-hidden />
      <span className="flex-1">Second language</span>
      <select
        value={lang}
        onChange={(e) => setLang(e.target.value as SecondLang)}
        className="rounded-md border border-white/15 bg-nav-active px-1.5 py-1 text-xs text-white"
      >
        {SECOND_LANGS.map(([code, name]) => <option key={code} value={code}>{name}</option>)}
      </select>
    </label>
  )
}
