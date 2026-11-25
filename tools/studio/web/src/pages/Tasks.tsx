import { useQuery } from '@tanstack/react-query'
import { Mail, Mic, PenLine } from 'lucide-react'
import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'
import { LEVELS } from '@/components/ui/level-tabs'
import { api, type SpeakingTask, type TaskPoint, type WritingTask } from '@/lib/api'
import { cn } from '@/lib/utils'

function Points({ points }: { points: TaskPoint[] }) {
  return (
    <ul className="m-0 flex list-none flex-col gap-1.5 p-0">
      {points.map((p, i) => (
        <li key={i} className="rounded-lg border border-line-soft px-3 py-1.5">
          <div className="flex flex-wrap items-baseline justify-between gap-2">
            <b>{p.label.tr}</b>
            <span className="text-xs text-muted">„{p.say}“</span>
          </div>
          <div className="mt-0.5 text-[11px] text-muted">counts if it contains: {p.keys.join(' · ')}</div>
        </li>
      ))}
    </ul>
  )
}

function Writing({ task }: { task: WritingTask }) {
  if (task.kind === 'form') {
    return (
      <div className="grid gap-4 lg:grid-cols-2">
        <div><h4 className="mt-0 mb-1 text-xs tracking-wider text-muted uppercase">Text</h4><p className="m-0 leading-relaxed">{task.text}</p></div>
        <div>
          <h4 className="mt-0 mb-1 text-xs tracking-wider text-muted uppercase">Form fields · accepted answers</h4>
          {task.fields?.map((f) => <div key={f.label} className="text-[13px]"><b>{f.label}:</b> {f.answers.join(' / ')}</div>)}
        </div>
      </div>
    )
  }
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="flex flex-col gap-2">
        <div className="font-medium">{task.prompt}</div>
        <div className="text-xs text-muted">{task.help?.tr}</div>
        <Points points={task.points || []} />
      </div>
      <div>
        <h4 className="mt-0 mb-1 text-xs tracking-wider text-muted uppercase">Sample · {task.sample?.split(/\s+/).length} words</h4>
        <p className="m-0 rounded-xl bg-sunken px-3 py-2.5 leading-relaxed">{task.sample}</p>
      </div>
    </div>
  )
}

function Speaking({ task }: { task: SpeakingTask }) {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="flex flex-col gap-2">
        <div className="font-medium">{task.prompt}</div>
        <div className="text-xs text-muted">{task.help.tr}</div>
        <Points points={task.points} />
      </div>
      <div>
        <h4 className="mt-0 mb-1 text-xs tracking-wider text-muted uppercase">Sample answer</h4>
        <p className="m-0 rounded-xl bg-sunken px-3 py-2.5 leading-relaxed">{task.sample}</p>
      </div>
    </div>
  )
}

export function Tasks() {
  const [params, setParams] = useSearchParams()
  const kind = params.get('kind') || 'writing'
  const level = params.get('level') || 'A1'
  const [open, setOpen] = useState<string | null>(null)
  const { data, error, isLoading } = useQuery({ queryKey: ['tasks'], queryFn: api.tasks })
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />

  const set = (next: Record<string, string>) => setParams({ kind, level, ...next }, { replace: true })
  const writing = data.writing.filter((t) => t.level === level)
  const speaking = data.speaking.filter((t) => t.level === level)
  const tabs: [string, string, number][] = [['writing', 'Writing', writing.length], ['speaking', 'Speaking', speaking.length], ['pattern', 'E-mail pattern', 0]]

  return (
    <>
      <PageHeader title="Writing & speaking" description="Exam-style tasks with the points the app checks and a sample answer." />
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div role="tablist" className="flex flex-wrap gap-1 rounded-xl bg-chip p-1">
          {tabs.map(([key, label, n]) => (
            <button key={key} role="tab" type="button" aria-selected={kind === key} onClick={() => set({ kind: key })}
              className={cn('rounded-lg px-3 py-1.5', kind === key ? 'bg-surface font-semibold shadow-sm' : 'text-ink-soft')}>
              {label}{key !== 'pattern' ? ` · ${n}` : ''}
            </button>
          ))}
        </div>
        {kind !== 'pattern' && (
          <div className="flex gap-1.5">
            {LEVELS.map((l) => (
              <button key={l} type="button" onClick={() => set({ level: l })}
                className={cn('rounded-full border px-3.5 py-1 text-[13px]', l === level ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}>
                {l}
              </button>
            ))}
          </div>
        )}
      </div>

      {kind === 'pattern' && data.pattern && (
        <div className="grid gap-4 lg:grid-cols-2">
          {(['informal', 'formal'] as const).map((style) => (
            <Card key={style} className="px-4 py-3.5">
              <h3 className="mt-0 mb-3 text-[15px] font-bold">{style === 'informal' ? 'du · friends and family' : 'Sie · offices, teachers, companies'}</h3>
              {data.pattern![style].map((b) => (
                <div key={b.title.en} className="mb-2.5">
                  <div className="text-xs font-semibold text-muted">{b.title.tr}</div>
                  <div className="flex flex-wrap gap-1">{b.phrases.map((p) => <Badge key={p} className="font-normal">{p}</Badge>)}</div>
                </div>
              ))}
            </Card>
          ))}
        </div>
      )}

      {kind !== 'pattern' && (
        <div className="flex flex-col gap-3">
          {(kind === 'writing' ? writing : speaking).map((t) => {
            const isOpen = open === t.id
            const Icon = kind === 'speaking' ? Mic : (t as WritingTask).kind === 'form' ? PenLine : Mail
            const meta = kind === 'speaking'
              ? `${(t as SpeakingTask).seconds} s · ${(t as SpeakingTask).points.length} points`
              : (t as WritingTask).kind === 'form' ? `form · ${(t as WritingTask).fields?.length} fields`
                : `${(t as WritingTask).minWords} words · ${(t as WritingTask).points?.length} points · ${(t as WritingTask).formal ? 'Sie' : 'du'}`
            return (
              <Card key={t.id} className="overflow-hidden">
                <button type="button" onClick={() => setOpen(isOpen ? null : t.id)} className="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-chip">
                  <span className="grid size-8 shrink-0 place-items-center rounded-full bg-chip text-ink-soft"><Icon className="size-4" aria-hidden /></span>
                  <span className="min-w-0 flex-1">
                    <span className="block font-semibold">{t.title.tr}</span>
                    <span className="block text-xs text-muted">{t.title.en} · {t.id}</span>
                  </span>
                  <span className="text-xs text-muted">{meta}</span>
                </button>
                {isOpen && (
                  <div className="border-t border-line-soft px-4 py-3.5">
                    {kind === 'speaking' ? <Speaking task={t as SpeakingTask} /> : <Writing task={t as WritingTask} />}
                  </div>
                )}
              </Card>
            )
          })}
          {!(kind === 'writing' ? writing : speaking).length && <div className="py-10 text-center text-muted">No {kind} tasks for {level}.</div>}
        </div>
      )}
    </>
  )
}
