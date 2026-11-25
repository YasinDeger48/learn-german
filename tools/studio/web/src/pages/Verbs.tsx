import { useQuery } from '@tanstack/react-query'
import { Search } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { buttonVariants } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { api, type Sentence, type VerbEntry } from '@/lib/api'
import { cn, percent } from '@/lib/utils'

const LEVELS = ['A1', 'A2', 'B1', 'B2']
const PERSONS = ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie/Sie']
const TENSES: Record<string, string> = { praesens: 'Präsens', praeteritum: 'Präteritum', perfekt: 'Perfekt', futur: 'Futur I' }

function Sentences({ title, items, tense }: { title: string; items: Sentence[]; tense?: boolean }) {
  return (
    <Card className="px-4 py-3.5">
      <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">{title}</h3>
      <ul className="m-0 flex list-none flex-col gap-2.5 p-0">
        {items.map((s, i) => (
          <li key={i}>
            {tense && s.t && <Badge className="mb-1">{TENSES[s.t] || s.t}</Badge>}
            <div className="font-medium">{s.de}</div>
            <div className="text-xs text-muted">{s.tr} · {s.en}</div>
            {s.note && <div className="mt-0.5 text-xs text-blue">{s.note}</div>}
          </li>
        ))}
      </ul>
    </Card>
  )
}

function Detail({ verb }: { verb: VerbEntry }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-1">
          <h2 className="m-0 text-3xl font-bold tracking-tight">{verb.v}</h2>
          <div className="text-muted">{verb.tr} · {verb.en}</div>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {verb.trennbar && <Badge tone="gold">separable</Badge>}
          {verb.reflexiv && <Badge tone="gold">reflexive</Badge>}
          {verb.rektion && <Badge>{verb.rektion}</Badge>}
        </div>
      </div>
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[520px] border-collapse">
            <thead>
              <tr className="text-left text-xs text-muted">
                <th className="px-4 py-2.5 font-semibold">Person</th>
                <th className="px-4 py-2.5 font-semibold">Präsens</th>
                <th className="px-4 py-2.5 font-semibold">Präteritum</th>
              </tr>
            </thead>
            <tbody>
              {PERSONS.map((p, i) => (
                <tr key={p} className="border-t border-line-soft">
                  <td className="px-4 py-2 text-muted">{p}</td>
                  <td className="px-4 py-2 font-semibold">{verb.praesens[i]}</td>
                  <td className="px-4 py-2 font-semibold">{verb.praeteritum[i]}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="grid gap-px border-t border-line-soft bg-line-soft sm:grid-cols-3">
          {[['Perfekt (er)', verb.perfekt], ['Futur I (er)', verb.futur], ['Imperativ (du · ihr · Sie)', verb.imperativ.join(' · ')]].map(([label, value]) => (
            <div key={label} className="bg-surface px-4 py-2.5">
              <div className="text-xs text-muted">{label}</div>
              <div className="font-semibold">{value}</div>
            </div>
          ))}
        </div>
      </Card>
      <div className="grid gap-4 lg:grid-cols-2">
        <Sentences title="Every tense" items={verb.examples} tense />
        <Sentences title="Complex sentences" items={verb.complex} />
        <Sentences title="Questions" items={verb.questions} />
        <Sentences title="Common phrases" items={verb.common} />
      </div>
    </div>
  )
}

export function Verbs() {
  const { level: levelParam, verb } = useParams()
  const level = (levelParam || 'A1').toUpperCase()
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [onlyReady, setOnlyReady] = useState(false)
  const { data, error, isLoading } = useQuery({ queryKey: ['verbs', level], queryFn: () => api.verbs(level) })

  const list = useMemo(() => {
    const q = query.trim().toLowerCase()
    return (data?.verbs || []).filter((v) => (!onlyReady || v.entry) && (!q || v.v.toLowerCase().includes(q) || v.meaning.toLowerCase().includes(q)))
  }, [data, query, onlyReady])
  const current = data?.verbs.find((v) => v.v === verb) || data?.verbs.find((v) => v.entry)

  return (
    <>
      <PageHeader
        title="Verb lab"
        description="Every verb with all its forms, sentences in every tense, questions, common phrases and complex sentences."
        actions={<Link to={`/inbox/${encodeURIComponent(`verbs:${level}`)}`} className={buttonVariants({ variant: 'outline' })}>{level} answers in the inbox</Link>}
      />
      <div className="mb-4 flex flex-wrap gap-2">
        {LEVELS.map((l) => (
          <button
            key={l}
            type="button"
            onClick={() => navigate(`/verbs/${l.toLowerCase()}`)}
            className={cn('rounded-xl border px-3.5 py-2 font-bold', l === level ? 'border-ink bg-ink text-ground' : 'border-line bg-surface')}
          >
            {l}
          </button>
        ))}
      </div>
      {isLoading && <Loading />}
      {(error || (!isLoading && !data)) && <Failed error={error} />}
      {data && (
        <div className="flex flex-wrap items-start gap-5 lg:flex-nowrap">
          <aside aria-label="Verbs" className="w-full shrink-0 overflow-hidden rounded-2xl border border-line bg-surface lg:sticky lg:top-6 lg:w-[300px]">
            <div className="flex flex-col gap-2 border-b border-line-soft p-3">
              <div className="flex items-center justify-between text-xs text-muted">
                <span>{data.ready} / {data.verbs.length} ready</span>
                <label className="flex items-center gap-1.5"><input type="checkbox" checked={onlyReady} onChange={(e) => setOnlyReady(e.target.checked)} />only ready</label>
              </div>
              <Progress value={percent(data.ready, data.verbs.length)} tone="blue" />
              <label className="flex h-9 items-center gap-2 rounded-lg border border-line px-2.5">
                <Search className="size-4 text-muted" aria-hidden />
                <span className="sr-only">Search verbs</span>
                <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search a verb or meaning" className="min-w-0 flex-1 bg-transparent outline-0" />
              </label>
            </div>
            <div className="max-h-[68vh] overflow-auto">
              {list.map((v) => (
                <button
                  key={v.v}
                  type="button"
                  disabled={!v.entry}
                  onClick={() => navigate(`/verbs/${level.toLowerCase()}/${encodeURIComponent(v.v)}`)}
                  className={cn(
                    'flex w-full items-center justify-between gap-2 border-b border-line-soft px-3.5 py-2 text-left',
                    v.v === current?.v ? 'bg-gold-soft' : v.entry ? 'hover:bg-chip' : 'cursor-default opacity-50',
                  )}
                >
                  <span className="min-w-0"><span className="font-semibold">{v.v}</span> <span className="text-xs text-muted">{v.meaning}</span></span>
                  {v.entry ? <span className="text-xs text-ok">✓</span> : <span className="text-[11px] text-muted">waiting</span>}
                </button>
              ))}
            </div>
          </aside>
          {current?.entry ? (
            <Detail key={current.v} verb={current.entry} />
          ) : (
            <div className="flex-1 py-16 text-center text-muted">No verb of {level} is ready yet. Answers come through the ChatGPT inbox.</div>
          )}
        </div>
      )}
    </>
  )
}
