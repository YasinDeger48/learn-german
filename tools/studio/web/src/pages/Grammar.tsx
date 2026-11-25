import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'
import { Editable } from '@/components/ui/editable'
import type { EditTarget } from '@/lib/api'
import { LevelTabs } from '@/components/ui/level-tabs'
import { api, type GrammarTopic } from '@/lib/api'
import { cn } from '@/lib/utils'

/** "Ich fahre mit ___ Bus" with the answer in place. */
function Filled({ q, answer }: { q: string; answer: string }) {
  const [before, after] = q.split('___')
  if (after === undefined) return <>{q} <b className="text-ok">→ {answer}</b></>
  return <>{before}<b className="rounded bg-ok-soft px-1 text-ok-ink">{answer}</b>{after}</>
}

function Topic({ topic, level }: { topic: GrammarTopic; level: string }) {
  const file = `${level.toLowerCase()}.json`
  const rule = (path: string): EditTarget => ({ file, collection: 'grammar', keyField: 'id', key: topic.id, path })
  const itemAt = (q: string, path: string): EditTarget => ({ file, collection: 'grammarItems', keyField: 'q', key: q, path })
  const refresh = ['grammar']
  const [onlyBroken, setOnlyBroken] = useState(false)
  const broken = topic.items.filter((i) => i.broken).length
  const items = onlyBroken ? topic.items.filter((i) => i.broken) : topic.items
  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div>
        <h2 className="m-0 text-2xl font-bold tracking-tight">{topic.de}</h2>
        <div className="text-muted">{topic.name.tr} · {topic.name.en}</div>
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Rule · Türkçe</h3>
          <p className="m-0 leading-relaxed whitespace-pre-line"><Editable multiline value={topic.rule.tr} target={rule('rule.tr')} refresh={refresh} /></p>
        </Card>
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Rule · English</h3>
          <p className="m-0 leading-relaxed whitespace-pre-line"><Editable multiline value={topic.rule.en} target={rule('rule.en')} refresh={refresh} /></p>
        </Card>
      </div>
      {topic.examples.length > 0 && (
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Examples</h3>
          {topic.examples.map((e, i) => (
            <div key={i} className="mb-1.5"><span className="font-medium">{e.de}</span> <span className="text-xs text-muted">— {e.tr} · {e.en}</span></div>
          ))}
        </Card>
      )}
      <Card className="overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line-soft px-4 py-3">
          <h3 className="m-0 text-[15px] font-bold">Exercises · {topic.items.length}</h3>
          {broken > 0 && (
            <label className="flex items-center gap-1.5 text-xs text-bad-ink">
              <input type="checkbox" checked={onlyBroken} onChange={(e) => setOnlyBroken(e.target.checked)} />only the {broken} with broken text
            </label>
          )}
        </div>
        <ol className="m-0 list-none p-0">
          {items.map((item, i) => (
            <li key={i} className={cn('border-t border-line-soft px-4 py-2.5 first:border-t-0', item.broken && 'bg-bad-soft/50')}>
              <div className="font-medium"><Filled q={item.q} answer={item.answer} /></div>
              <div className="mt-0.5 flex flex-wrap gap-1">
                {item.options.slice(1).map((o) => <Badge key={o} className="px-2 py-0 font-normal">{o}</Badge>)}
              </div>
              <div className="mt-1 text-xs text-muted"><Editable multiline value={item.why.tr || ''} target={itemAt(item.q, 'why.tr')} refresh={refresh} /></div>
              {item.why.en && <div className={cn('text-xs', item.broken ? 'font-semibold text-bad-ink' : 'text-muted')}><Editable multiline value={item.why.en} target={itemAt(item.q, 'why.en')} refresh={refresh} /></div>}
            </li>
          ))}
        </ol>
      </Card>
    </div>
  )
}

export function Grammar() {
  const { level: param, topic: topicParam } = useParams()
  const level = (param || 'A1').toUpperCase()
  const navigate = useNavigate()
  const { data, error, isLoading } = useQuery({ queryKey: ['grammar', level], queryFn: () => api.grammar(level) })
  const topic = data?.topics.find((t) => String(t.id) === topicParam) || data?.topics[0]

  return (
    <>
      <PageHeader title="Grammar" description="Topics with their rule, examples and every exercise. The first option is the correct one." />
      <LevelTabs level={level} onChange={(l) => navigate(`/grammar/${l.toLowerCase()}`)} />
      {isLoading && <Loading />}
      {(error || (!isLoading && !data)) && <Failed error={error} />}
      {data && data.broken > 0 && (
        <div className="mb-4 rounded-xl bg-bad-soft px-4 py-2.5 text-[13px] text-bad-ink">
          {data.broken} exercises of {level} have broken characters in their explanation (for example „w??rde“ instead of „würde“). They show in red.
        </div>
      )}
      {data && (
        <div className="flex flex-wrap items-start gap-5 lg:flex-nowrap">
          <aside aria-label="Topics" className="w-full shrink-0 overflow-hidden rounded-2xl border border-line bg-surface lg:sticky lg:top-6 lg:w-[320px]">
            {data.topics.map((t) => {
              const broken = t.items.filter((i) => i.broken).length
              return (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => navigate(`/grammar/${level.toLowerCase()}/${t.id}`)}
                  className={cn('flex w-full items-start justify-between gap-2 border-b border-line-soft px-3.5 py-2.5 text-left last:border-b-0', t.id === topic?.id ? 'bg-gold-soft' : 'hover:bg-chip')}
                >
                  <span className="min-w-0">
                    <span className="block font-semibold">{t.de}</span>
                    <span className="block truncate text-xs text-muted">{t.name.tr}</span>
                  </span>
                  <span className="flex shrink-0 flex-col items-end gap-0.5 text-xs text-muted">
                    {t.items.length}
                    {broken > 0 && <Badge tone="bad" className="px-1.5 py-0">{broken}</Badge>}
                  </span>
                </button>
              )
            })}
          </aside>
          {topic && <Topic key={`${level}-${topic.id}`} topic={topic} level={level} />}
        </div>
      )}
    </>
  )
}
