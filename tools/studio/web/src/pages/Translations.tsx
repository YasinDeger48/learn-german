import { useQuery } from '@tanstack/react-query'
import { RefreshCw } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardHeader } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { api } from '@/lib/api'
import { cn, fmt, percent } from '@/lib/utils'

function Cell({ done, total, to }: { done: number; total: number; to?: string }) {
  const p = percent(done, total)
  const body = (
    <div className="flex min-w-[120px] flex-col gap-1">
      <div className="flex justify-between text-xs"><b className="tabular-nums">{p}%</b><span className="text-muted tabular-nums">{fmt(done)} / {fmt(total)}</span></div>
      <Progress value={p} className="h-1.5" />
    </div>
  )
  return to ? <Link to={to} className="text-ink no-underline">{body}</Link> : body
}

export function Translations() {
  const [lang, setLang] = useState('es')
  const [round, setRound] = useState(0)
  const stats = useQuery({ queryKey: ['translations'], queryFn: () => api.translations() })
  const sample = useQuery({ queryKey: ['translations', lang, round], queryFn: () => api.translations(lang) })

  if (stats.isLoading) return <Loading />
  if (stats.error || !stats.data) return <Failed error={stats.error} />
  const sets = stats.data.languages[0]?.sets.map((s) => s.set) || []
  const current = stats.data.languages.find((l) => l.code === lang)

  return (
    <>
      <PageHeader title="Translations" description="Turkish and English are complete. The other languages show English until their translation arrives." />
      <div className="flex flex-col gap-5">
        <Card className="overflow-hidden">
          <CardHeader title="Progress" action={<span className="text-xs text-muted">Click a cell to open its ChatGPT job</span>} />
          <div className="overflow-x-auto">
            <table className="w-full min-w-[820px] border-collapse">
              <thead>
                <tr className="text-left text-xs text-muted">
                  <th className="px-4 py-2.5 font-semibold">Language</th>
                  <th className="px-3 py-2.5 font-semibold">App texts</th>
                  {sets.map((s) => <th key={s} className="px-3 py-2.5 font-semibold">{s.toUpperCase()} content</th>)}
                </tr>
              </thead>
              <tbody>
                {stats.data.languages.map((l) => (
                  <tr key={l.code} className={cn('border-t border-line-soft', l.code === lang && 'bg-gold-soft/50')}>
                    <td className="px-4 py-3"><button type="button" onClick={() => setLang(l.code)} className="font-semibold">{l.name}</button></td>
                    <td className="px-3 py-3"><Cell done={l.ui.done} total={l.ui.total} to={`/inbox/${encodeURIComponent(`tr:${l.code}:ui`)}`} /></td>
                    {l.sets.map((s) => (
                      <td key={s.set} className="px-3 py-3"><Cell done={s.done} total={s.total} to={`/inbox/${encodeURIComponent(`tr:${l.code}:${s.set}`)}`} /></td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>

        <Card className="overflow-hidden">
          <CardHeader
            title={`Spot check · ${current?.name || lang}`}
            action={
              <div className="flex items-center gap-2">
                <div className="flex gap-1">
                  {stats.data.languages.map((l) => (
                    <button key={l.code} type="button" onClick={() => setLang(l.code)}
                      className={cn('rounded-full border px-2.5 py-0.5 text-xs', l.code === lang ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}>
                      {l.code}
                    </button>
                  ))}
                </div>
                <Button size="sm" onClick={() => setRound(round + 1)}><RefreshCw />New sample</Button>
              </div>
            }
          />
          {sample.isLoading && <Loading />}
          {sample.data?.sample && (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[760px] border-collapse text-[13px]">
                <thead>
                  <tr className="text-left text-xs text-muted">
                    <th className="w-[34%] px-4 py-2 font-semibold">English (source)</th>
                    <th className="w-[30%] px-2 py-2 font-semibold">Türkçe</th>
                    <th className="px-4 py-2 font-semibold">{current?.name}</th>
                  </tr>
                </thead>
                <tbody>
                  {sample.data.sample.map((p, i) => (
                    <tr key={i} className="border-t border-line-soft align-top">
                      <td className="px-4 py-2"><Badge className="mr-1.5 px-1.5 py-0">{p.where}</Badge>{p.en}</td>
                      <td className="px-2 py-2 text-muted">{p.tr}</td>
                      <td className="px-4 py-2 font-medium" dir={lang === 'ar' ? 'rtl' : undefined}>{p.text}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {!sample.data.sample.length && <div className="p-8 text-center text-muted">Nothing translated yet.</div>}
            </div>
          )}
        </Card>
      </div>
    </>
  )
}
