import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { buttonVariants } from '@/components/ui/button'
import { Card, CardBody, CardHeader } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { api, type JobRow, type Overview as Data } from '@/lib/api'
import { fmt, percent } from '@/lib/utils'

function Kpi({ label, value, note, pct, tone }: { label: string; value: string; note: string; pct: number; tone: 'ok' | 'gold' | 'blue' }) {
  return (
    <div className="flex flex-col gap-1.5 rounded-2xl border border-line bg-surface px-[18px] py-4">
      <div className="text-[13px] font-medium text-muted">{label}</div>
      <div className="text-[28px] font-bold tracking-tight">{value}</div>
      <Progress value={pct} tone={tone} />
      <div className="text-xs text-muted">{note}</div>
    </div>
  )
}

function jobStatus(job: JobRow) {
  if (job.answers === 0) return <Badge>Waiting</Badge>
  if (job.answers >= job.requests) return <Badge tone="ok">All answered</Badge>
  return <Badge tone="gold">{job.requests - job.answers} to go</Badge>
}

function Jobs({ data }: { data: Data }) {
  // One row per kind: verb levels together, translations together per set.
  const rows = data.jobs.filter((j) => j.requests > 0)
  return (
    <Card className="min-w-0 flex-[2_1_520px] overflow-hidden">
      <CardHeader
        title="Waiting for ChatGPT"
        action={<Link to="/inbox" className="text-[13px] font-semibold text-blue no-underline">Open inbox</Link>}
      />
      <div className="overflow-x-auto">
        <table className="w-full min-w-[520px] border-collapse">
          <thead>
            <tr className="text-left text-xs text-muted">
              <th className="px-[18px] py-2.5 font-semibold">Job</th>
              <th className="px-2 py-2.5 font-semibold">Answered</th>
              <th className="px-2 py-2.5 font-semibold">In the app</th>
              <th className="px-[18px] py-2.5 text-right font-semibold">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((job) => (
              <tr key={job.id} className="border-t border-line-soft">
                <td className="px-[18px] py-2.5">
                  <Link to={job.id.startsWith('pictures') ? '/media' : `/inbox/${encodeURIComponent(job.id)}`} className="font-semibold text-ink no-underline hover:underline">
                    {job.title}
                  </Link>
                  <div className="text-xs text-muted">{job.group}</div>
                </td>
                <td className="px-2 py-2.5 tabular-nums">{job.answers} / {job.requests}</td>
                <td className="px-2 py-2.5 tabular-nums">{job.progress ? `${fmt(job.progress[0])} / ${fmt(job.progress[1])}` : '—'}</td>
                <td className="px-[18px] py-2.5 text-right">{jobStatus(job)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  )
}

function Levels({ data }: { data: Data }) {
  return (
    <Card className="overflow-hidden">
      <CardHeader title="Content by level" />
      <div className="overflow-x-auto">
        <table className="w-full min-w-[760px] border-collapse">
          <thead>
            <tr className="text-left text-xs text-muted">
              {['Level', 'Daily texts', 'Words', 'Grammar', 'Path units', 'Verb lab', 'Writing', 'Speaking'].map((h) => (
                <th key={h} className="px-[18px] py-2.5 font-semibold first:pl-[18px]">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.levels.map((r) => (
              <tr key={r.level} className="border-t border-line-soft tabular-nums">
                <td className="px-[18px] py-3"><Badge tone="level">{r.level}</Badge></td>
                <td className="px-[18px] py-3">{r.texts}<span className="text-xs text-muted"> · {r.covers} covers</span></td>
                <td className="px-[18px] py-3">{fmt(r.words)}</td>
                <td className="px-[18px] py-3">{r.grammarTopics} topics · {fmt(r.grammarItems)}</td>
                <td className="px-[18px] py-3">{r.units}</td>
                <td className="px-[18px] py-3">{r.verbsReady} / {r.verbsTotal}</td>
                <td className="px-[18px] py-3">{r.writing}</td>
                <td className="px-[18px] py-3">{r.speaking}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  )
}

export function Overview() {
  const { data, error, isLoading } = useQuery({ queryKey: ['overview'], queryFn: api.overview })
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />

  const texts = data.levels.reduce((s, l) => s + l.texts, 0)
  const covers = data.levels.reduce((s, l) => s + l.covers, 0)
  const reviewed = data.levels.reduce((s, l) => s + l.reviewed, 0)
  const audio = data.audio.female + data.audio.male + data.audio.words
  const verbsByLevel = data.levels.map((l) => `${l.level} ${l.verbsReady}`).join(' · ')

  return (
    <>
      <PageHeader
        title="Overview"
        description="Everything the app ships: content, pictures, audio and what ChatGPT still owes."
        actions={<Link to="/publish" className={buttonVariants({ variant: 'primary' })}>Publish</Link>}
      />
      <div className="flex flex-col gap-5">
        <section aria-label="Key numbers" className="grid grid-cols-[repeat(auto-fit,minmax(210px,1fr))] gap-3.5">
          <Kpi label="Daily texts" value={fmt(texts)} pct={percent(covers, texts)} tone="ok" note={`${covers} with a cover · ${reviewed} reviewed`} />
          <Kpi label="Path units" value={String(data.units.total)} pct={percent(data.units.pictures, data.units.total)} tone="gold"
            note={`Pictures ${data.units.pictures} / ${data.units.total} · word cards ${data.units.cards} / ${data.units.cardsTotal}`} />
          <Kpi label="Verb lab" value={`${fmt(data.verbs.ready)} / ${fmt(data.verbs.total)}`} pct={percent(data.verbs.ready, data.verbs.total)} tone="blue" note={verbsByLevel} />
          <Kpi label="Audio" value={fmt(audio)} pct={100} tone="ok"
            note={`${data.audio.female + data.audio.male} text recordings · ${fmt(data.audio.words)} words · ${data.audio.ambience} backgrounds`} />
        </section>

        <div className="flex flex-wrap gap-[18px]">
          <Jobs data={data} />
          <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-[18px]">
            <Card>
              <CardHeader title="Translations · app texts" action={<Link to="/translations" className="text-[13px] font-semibold text-blue no-underline">Details</Link>} />
              <CardBody className="flex flex-col gap-2">
                {data.languages.map((l) => (
                  <div key={l.code} className="grid grid-cols-[96px_1fr_44px] items-center gap-2.5">
                    <div className="font-medium">{l.name}</div>
                    <Progress value={l.percent} className="h-2" />
                    <div className="text-right text-xs text-muted tabular-nums">{l.percent}%</div>
                  </div>
                ))}
              </CardBody>
            </Card>
            <Card>
              <CardHeader title="Recent saves" />
              <CardBody className="flex flex-col py-2">
                {data.commits.map((c) => (
                  <div key={c.id} className="flex gap-2.5 border-t border-line-soft py-2 text-[13px] first:border-t-0">
                    <code className="text-xs text-muted">{c.id}</code>
                    <span className="min-w-0 truncate" title={c.message}>{c.message}</span>
                  </div>
                ))}
              </CardBody>
            </Card>
          </div>
        </div>

        <Levels data={data} />
      </div>
    </>
  )
}
