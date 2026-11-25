import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query'
import { ClipboardCopy, FolderOpen, Import } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardHeader } from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { useToast } from '@/components/ui/toast'
import { api, type CheckResult, type InboxJob } from '@/lib/api'
import { cn, fmt, pad2, percent } from '@/lib/utils'

type Filter = 'all' | 'open' | 'problems'

function CheckBadge({ result, answered }: { result?: CheckResult; answered: boolean }) {
  if (!answered) return <Badge>Waiting for ChatGPT</Badge>
  if (!result) return <Badge>Checking…</Badge>
  if (!result.problems.length) return <Badge tone="ok">✓ {result.ok} / {result.lines} fine</Badge>
  return <Badge tone="bad">{result.ok} / {result.lines} fine · {result.problems.length} problem{result.problems.length > 1 ? 's' : ''}</Badge>
}

function JobList({ jobs, current, filter, setFilter }: { jobs: InboxJob[]; current?: string; filter: Filter; setFilter: (f: Filter) => void }) {
  const shown = jobs.filter((j) => filter === 'all' || (filter === 'open' ? j.answers.length < j.requests.length : j.answers.length > 0))
  const groups = [...new Set(shown.map((j) => j.group))]
  const chip = (key: Filter, label: string) => (
    <button
      key={key}
      type="button"
      onClick={() => setFilter(key)}
      className={cn('rounded-full border px-3 py-1 text-xs', filter === key ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}
    >
      {label}
    </button>
  )
  return (
    <aside aria-label="Jobs" className="w-full shrink-0 rounded-2xl border border-line bg-surface py-4 lg:w-[300px]">
      <div className="px-[18px] pb-3 text-lg font-bold">Jobs</div>
      <div className="flex flex-wrap gap-1.5 px-[18px] pb-2">{[chip('all', 'All'), chip('open', 'Needs ChatGPT'), chip('problems', 'Has answers')]}</div>
      {groups.map((group) => (
        <div key={group}>
          <div className="px-[18px] pt-3.5 pb-1.5 text-[11px] uppercase tracking-[.08em] text-muted">{group}</div>
          {shown.filter((j) => j.group === group).map((j) => {
            const on = j.id === current
            const done = j.progress ? percent(j.progress[0], j.progress[1]) : percent(j.answers.length, j.requests.length)
            return (
              <Link
                key={j.id}
                to={`/inbox/${encodeURIComponent(j.id)}`}
                className={cn('block border-l-[3px] py-2.5 pr-[18px] pl-[15px] text-ink no-underline', on ? 'border-gold bg-gold-soft' : 'border-transparent hover:bg-chip')}
              >
                <div className="flex justify-between gap-2">
                  <span className="font-semibold">{j.title}</span>
                  <span className="text-xs text-muted tabular-nums">{j.answers.length} / {j.requests.length}</span>
                </div>
                <Progress value={done} className="mt-1.5 h-1" />
              </Link>
            )
          })}
        </div>
      ))}
      {!shown.length && <div className="px-[18px] py-6 text-muted">Nothing here.</div>}
    </aside>
  )
}

function Steps() {
  const steps = [
    ['Copy', 'the request into ChatGPT'],
    ['Paste', 'the whole answer here'],
    ['Check', 'problems show in red'],
    ['Import', 'then Publish'],
  ]
  return (
    <ol className="m-0 grid list-none grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-2.5 p-0">
      {steps.map(([title, sub], i) => (
        <li key={title} className="flex items-center gap-2.5 rounded-xl border border-line bg-surface px-3.5 py-3">
          <span className={cn('grid size-[26px] shrink-0 place-items-center rounded-full text-[13px] font-bold', i === 0 ? 'bg-gold text-on-gold' : 'bg-chip text-ink-soft')}>{i + 1}</span>
          <span><b className="font-semibold">{title}</b><br /><span className="text-xs text-muted">{sub}</span></span>
        </li>
      ))}
    </ol>
  )
}

function JobDetail({ job }: { job: InboxJob }) {
  const toast = useToast()
  const client = useQueryClient()
  const firstOpen = job.requests.find((n) => !job.answers.includes(n)) ?? job.requests[0]
  const [n, setN] = useState<number>(firstOpen)
  const [answer, setAnswer] = useState('')
  const [output, setOutput] = useState('')
  useEffect(() => { setN(firstOpen); setAnswer(''); setOutput('') }, [job.id]) // eslint-disable-line react-hooks/exhaustive-deps

  const checks = useQueries({
    queries: job.answers.map((a) => ({ queryKey: ['check', job.id, a], queryFn: () => api.check(job.id, a), staleTime: 60_000 })),
  })
  const checkOf = useMemo(() => {
    const map = new Map<number, CheckResult>()
    job.answers.forEach((a, i) => checks[i]?.data && map.set(a, checks[i].data!))
    return map
  }, [job.answers, checks])
  const current = checkOf.get(n)
  const fine = job.answers.filter((a) => checkOf.get(a) && !checkOf.get(a)!.problems.length).length

  const refresh = () => Promise.all([client.invalidateQueries({ queryKey: ['inbox'] }), client.invalidateQueries({ queryKey: ['overview'] })])

  const copy = async (number: number) => {
    const { text } = await api.request(job.id, number)
    await navigator.clipboard.writeText(text)
    setN(number)
    toast(`Request ${pad2(number)} copied: paste it into ChatGPT`)
  }
  const save = useMutation({
    mutationFn: () => api.saveAnswer(job.id, n, answer),
    onSuccess: async (result) => {
      client.setQueryData(['check', job.id, n], result)
      toast(result.problems.length ? 'Saved, but there are problems (see red)' : 'Saved: all lines fine')
      setAnswer('')
      await refresh()
    },
    onError: (e) => toast(`Not saved: ${(e as Error).message}`),
  })
  const run = useMutation({
    mutationFn: () => api.importJob(job.id),
    onSuccess: async (r) => {
      setOutput(r.output || 'Done.')
      toast('Imported. Check the output, then Publish.')
      await client.invalidateQueries({ queryKey: ['check', job.id] })
      await refresh()
    },
    onError: (e) => toast((e as Error).message),
  })

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-[18px]">
      <PageHeader
        eyebrow={job.group}
        title={job.title}
        description={`${job.requests.length} requests · ${job.answers.length} answered${job.progress ? ` · ${fmt(job.progress[0])} / ${fmt(job.progress[1])} in the app` : ''}`}
        actions={<>
          <Button onClick={() => api.openFolder(job.id).catch((e) => toast(e.message))}><FolderOpen />Open folder</Button>
          <Button variant="primary" disabled={!fine || run.isPending} onClick={() => run.mutate()}>
            <Import />{run.isPending ? 'Importing…' : `Import ${fine} checked answer${fine === 1 ? '' : 's'}`}
          </Button>
        </>}
      />
      <Steps />

      <Card className="flex flex-col gap-3 px-[18px] py-4">
        <div className="flex flex-wrap items-center gap-2.5">
          <label htmlFor="request" className="font-bold">Request</label>
          <select id="request" value={n} onChange={(e) => setN(Number(e.target.value))} className="h-9 rounded-lg border border-line bg-surface px-2">
            {job.requests.map((r) => (
              <option key={r} value={r}>{pad2(r)}{job.answers.includes(r) ? ' ✓' : ''}</option>
            ))}
          </select>
          <Button variant="gold" size="sm" onClick={() => copy(n).catch((e) => toast(e.message))}><ClipboardCopy />Copy for ChatGPT</Button>
          <span className="flex-1" />
          <CheckBadge result={current} answered={job.answers.includes(n)} />
        </div>
        <label htmlFor="answer" className="text-[13px] font-semibold">ChatGPT's answer for request {pad2(n)}</label>
        <textarea
          id="answer"
          value={answer}
          onChange={(e) => setAnswer(e.target.value)}
          placeholder="Paste the whole answer here. Code blocks are fine."
          className="min-h-[160px] resize-y rounded-[10px] border border-line bg-sunken px-3 py-2.5 font-mono text-xs leading-normal"
        />
        <div className="flex flex-wrap items-center gap-2.5">
          <Button variant="primary" disabled={!answer.trim() || save.isPending} onClick={() => save.mutate()}>
            {save.isPending ? 'Saving…' : 'Save and check'}
          </Button>
          <span className="text-xs text-muted">Same rules as the command line: JSON, every field, irregular forms, template sentences, placeholders.</span>
        </div>
        {current && current.problems.length > 0 && (
          <ul className="m-0 max-h-[240px] overflow-auto rounded-xl bg-bad-soft py-2.5 pr-3 pl-7 text-[13px] text-bad-ink">
            {current.problems.slice(0, 50).map((p, i) => <li key={i}>{p}</li>)}
            {current.problems.length > 50 && <li>… {current.problems.length - 50} more</li>}
          </ul>
        )}
      </Card>

      {output && <pre className="m-0 max-h-[300px] overflow-auto rounded-xl border border-line bg-surface p-3 text-xs whitespace-pre-wrap">{output}</pre>}

      <Card className="overflow-hidden">
        <CardHeader title="All requests" />
        <div className="overflow-x-auto">
          <table className="w-full min-w-[480px] border-collapse">
            <tbody>
              {job.requests.map((r) => (
                <tr key={r} className={cn('border-t border-line-soft first:border-t-0', r === n && 'bg-gold-soft/60')}>
                  <td className="w-14 px-[18px] py-2.5 font-semibold tabular-nums">{pad2(r)}</td>
                  <td className="px-2 py-2.5"><CheckBadge result={checkOf.get(r)} answered={job.answers.includes(r)} /></td>
                  <td className="px-[18px] py-2.5 text-right whitespace-nowrap">
                    <Button size="sm" onClick={() => copy(r).catch((e) => toast(e.message))}>Copy</Button>{' '}
                    <Button size="sm" onClick={() => { setN(r); document.getElementById('answer')?.focus() }}>Paste answer</Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}

export function Inbox() {
  const { job: jobId } = useParams()
  const navigate = useNavigate()
  const [filter, setFilter] = useState<Filter>('all')
  const { data, error, isLoading } = useQuery({ queryKey: ['inbox'], queryFn: api.inbox })
  const job = data?.jobs.find((j) => j.id === jobId)

  useEffect(() => {
    if (data && !jobId && data.jobs.length) navigate(`/inbox/${encodeURIComponent(data.jobs[0].id)}`, { replace: true })
  }, [data, jobId, navigate])

  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  return (
    <div className="flex flex-wrap items-start gap-5 lg:flex-nowrap">
      <JobList jobs={data.jobs} current={jobId} filter={filter} setFilter={setFilter} />
      {job ? <JobDetail key={job.id} job={job} /> : <div className="flex-1 py-16 text-center text-muted">Choose a job on the left.</div>}
    </div>
  )
}
