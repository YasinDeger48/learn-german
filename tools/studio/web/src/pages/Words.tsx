import { useQuery } from '@tanstack/react-query'
import { Search } from 'lucide-react'
import { Fragment, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Editable } from '@/components/ui/editable'
import { LevelTabs } from '@/components/ui/level-tabs'
import { api } from '@/lib/api'
import { cn, fmt } from '@/lib/utils'

const ARTICLE: Record<string, string> = { der: 'text-[#2F5BEA]', die: 'text-[#C8323A]', das: 'text-[#157A41]' }
const TYPES = [
  ['', 'All'],
  ['der', 'der'],
  ['die', 'die'],
  ['das', 'das'],
  ['verb', 'Verbs'],
  ['other', 'Other'],
] as const
const PAGE = 200

export function Words() {
  const { level: param } = useParams()
  const level = (param || 'A1').toUpperCase()
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [theme, setTheme] = useState('')
  const [type, setType] = useState('')
  const [open, setOpen] = useState<number | null>(null)
  const [limit, setLimit] = useState(PAGE)
  const { data, error, isLoading } = useQuery({ queryKey: ['words', level], queryFn: () => api.words(level) })

  const file = `${level.toLowerCase()}.json`
  const at = (id: number, path: string) => ({ file, collection: 'words', keyField: 'id', key: id, path })
  const refresh = ['words']

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase()
    return (data?.words || []).filter((w) => {
      if (theme && w.theme !== theme) return false
      if (type === 'other' ? ['der', 'die', 'das', 'verb'].includes(w.type) : type && w.type !== type) return false
      return !q || w.de.toLowerCase().includes(q) || w.tr.toLowerCase().includes(q) || w.en.toLowerCase().includes(q)
    })
  }, [data, query, theme, type])

  return (
    <>
      <PageHeader title="Words" description="The word list of each level. Hover a meaning, plural or example and click the pencil to change it." />
      <LevelTabs level={level} onChange={(l) => { navigate(`/words/${l.toLowerCase()}`); setTheme(''); setLimit(PAGE) }} />
      {isLoading && <Loading />}
      {(error || (!isLoading && !data)) && <Failed error={error} />}
      {data && (
        <Card className="overflow-hidden">
          <div className="flex flex-wrap items-center gap-2.5 border-b border-line-soft px-4 py-3">
            <label className="flex h-9 min-w-[220px] flex-1 items-center gap-2 rounded-lg border border-line px-2.5">
              <Search className="size-4 text-muted" aria-hidden />
              <span className="sr-only">Search words</span>
              <input value={query} onChange={(e) => { setQuery(e.target.value); setLimit(PAGE) }} placeholder="Search German, Turkish or English" className="min-w-0 flex-1 bg-transparent outline-0" />
            </label>
            <label className="sr-only" htmlFor="theme">Theme</label>
            <select id="theme" value={theme} onChange={(e) => { setTheme(e.target.value); setLimit(PAGE) }} className="h-9 max-w-[260px] rounded-lg border border-line bg-surface px-2">
              <option value="">All themes</option>
              {data.themes.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
            <div className="flex gap-1">
              {TYPES.map(([key, label]) => (
                <button key={key} type="button" onClick={() => { setType(key); setLimit(PAGE) }}
                  className={cn('rounded-full border px-2.5 py-1 text-xs', type === key ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}>
                  {label}
                </button>
              ))}
            </div>
            <span className="text-xs text-muted">{fmt(rows.length)} words</span>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] border-collapse">
              <thead>
                <tr className="text-left text-xs text-muted">
                  <th className="px-4 py-2.5 font-semibold">Word</th>
                  <th className="px-2 py-2.5 font-semibold">Plural</th>
                  <th className="px-2 py-2.5 font-semibold">Türkçe</th>
                  <th className="px-2 py-2.5 font-semibold">English</th>
                  <th className="px-4 py-2.5 font-semibold">Theme</th>
                </tr>
              </thead>
              <tbody>
                {rows.slice(0, limit).map((w) => (
                  <Fragment key={w.id}>
                    <tr onClick={() => setOpen(open === w.id ? null : w.id)} className={cn('cursor-pointer border-t border-line-soft hover:bg-chip', open === w.id && 'bg-gold-soft/60')}>
                      <td className="px-4 py-2">
                        {ARTICLE[w.type] ? <span className={ARTICLE[w.type]}>{w.type} </span> : null}
                        <b>{w.de}</b>
                        {w.type === 'verb' && <Badge className="ml-1.5 px-1.5 py-0">verb</Badge>}
                        {w.broken && <Badge tone="bad" className="ml-1.5 px-1.5 py-0">broken text</Badge>}
                      </td>
                      <td className="px-2 py-2 text-muted">{w.plural ? <Editable value={w.plural} target={at(w.id, 'plural')} refresh={refresh} /> : ''}</td>
                      <td className="px-2 py-2"><Editable value={w.tr} target={at(w.id, 'mean.tr')} refresh={refresh} /></td>
                      <td className="px-2 py-2 text-ink-soft"><Editable value={w.en} target={at(w.id, 'mean.en')} refresh={refresh} /></td>
                      <td className="px-4 py-2 text-xs text-muted">{w.theme}</td>
                    </tr>
                    {open === w.id && (
                      <tr className="bg-sunken">
                        <td colSpan={5} className="px-4 py-3">
                          <div className="mb-1.5 text-xs text-muted">Pronunciation help: [{w.pron}] · id {w.id}</div>
                          {w.examples.map((e, i) => (
                            <div key={i} className="mb-2.5 grid gap-0.5">
                              <Editable className="font-medium" value={e.de} target={at(w.id, `ex.${i}.de`)} refresh={refresh} />
                              <Editable className="text-xs text-muted" value={e.tr} target={at(w.id, `ex.${i}.mean.tr`)} refresh={refresh} />
                              <Editable className="text-xs text-muted" value={e.en} target={at(w.id, `ex.${i}.mean.en`)} refresh={refresh} />
                            </div>
                          ))}
                          {!w.examples.length && <div className="text-muted">No examples.</div>}
                        </td>
                      </tr>
                    )}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>
          {rows.length > limit && (
            <div className="border-t border-line-soft p-3 text-center">
              <Button onClick={() => setLimit(limit + PAGE)}>Show {Math.min(PAGE, rows.length - limit)} more</Button>
            </div>
          )}
        </Card>
      )}
    </>
  )
}
