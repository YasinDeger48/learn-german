import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Check, ClipboardCopy, ImageOff, Save, Trash2, Wrench, X } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { DropZone } from '@/components/ui/drop-zone'
import { Editable } from '@/components/ui/editable'
import { useToast } from '@/components/ui/toast'
import { api, type Glossary, type TextDetail, type TextRow } from '@/lib/api'
import { langDir, langName, useSecondLang } from '@/lib/lang'
import { cn } from '@/lib/utils'

const FILTERS = [
  ['all', 'All'],
  ['nocover', 'No cover'],
  ['issues', 'Issues'],
  ['open', 'Not reviewed'],
  ['fix', 'To fix'],
  ['ok', 'Approved'],
] as const
type Filter = (typeof FILTERS)[number][0]

function matches(t: TextRow, filter: Filter) {
  const status = t.review.status
  switch (filter) {
    case 'nocover': return !t.cover
    case 'issues': return t.issues.length > 0
    case 'open': return !status
    case 'fix': return status === 'fix'
    case 'ok': return status === 'ok'
    default: return true
  }
}

function StatusDot({ status }: { status?: string }) {
  return <span className={cn('inline-block size-2 rounded-full', status === 'ok' ? 'bg-ok' : status === 'fix' ? 'bg-gold' : 'bg-line')} aria-hidden />
}

/** German text with the glossary words marked. */
function Marked({ text, glossary }: { text: string; glossary: Glossary[] }) {
  const forms = [...new Set(glossary.map((g) => g.form))].filter(Boolean).sort((a, b) => b.length - a.length)
  if (!forms.length) return <>{text}</>
  const escaped = forms.map((f) => f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
  const re = new RegExp(`(?<![\\p{L}])(${escaped.join('|')})(?![\\p{L}])`, 'gu')
  const parts = text.split(re)
  return <>{parts.map((part, i) => (i % 2 ? <mark key={i} className="rounded bg-blue/15 px-0.5 text-inherit">{part}</mark> : part))}</>
}

function Detail({ id, bust, onBust, onReviewed }: { id: string; bust: number; onBust: () => void; onReviewed: (status: string) => void }) {
  const [second] = useSecondLang()
  const toast = useToast()
  const client = useQueryClient()
  const { data, error, isLoading } = useQuery({ queryKey: ['text', id], queryFn: () => api.text(id) })
  const [note, setNote] = useState('')
  const [crop, setCrop] = useState(false)
  useEffect(() => setNote(data?.review.note || ''), [data])

  const refresh = async () => {
    onBust()
    await Promise.all(['text', 'texts', 'textSummary', 'overview'].map((key) => client.invalidateQueries({ queryKey: [key] })))
  }
  const upload = useMutation({
    mutationFn: (file: File) => api.putCover(id, file, crop ? 0.08 : 0),
    onSuccess: async () => { toast('Cover saved'); await refresh() },
    onError: (e) => toast(`Not saved: ${(e as Error).message}`),
  })
  const review = useMutation({
    mutationFn: (status: '' | 'ok' | 'fix') => api.review(id, status, note),
    onSuccess: async (_, status) => {
      toast(status === 'ok' ? 'Approved' : status === 'fix' ? 'Marked to fix' : 'Cleared')
      await refresh()
      onReviewed(status)
    },
  })

  // Paste a picture (Ctrl+V) to use it as the cover; A / F review, unless typing.
  useEffect(() => {
    const paste = (e: ClipboardEvent) => {
      const file = [...(e.clipboardData?.files || [])].find((f) => f.type.startsWith('image/'))
      if (file) upload.mutate(file)
    }
    const key = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName
      if (tag === 'TEXTAREA' || tag === 'INPUT' || tag === 'SELECT' || e.ctrlKey || e.metaKey) return
      if (e.key === 'a' || e.key === 'A') review.mutate('ok')
      if (e.key === 'f' || e.key === 'F') review.mutate('fix')
    }
    document.addEventListener('paste', paste)
    document.addEventListener('keydown', key)
    return () => { document.removeEventListener('paste', paste); document.removeEventListener('keydown', key) }
  }) // eslint-disable-line react-hooks/exhaustive-deps

  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const t: TextDetail['text'] = data.text
  const at = (path: string) => ({ file: `daily_${data.level.toLowerCase()}.json`, collection: 'texts', keyField: 'id', key: t.id, path })
  const editRefresh = ['text', 'texts']
  const trans = t.trans || []
  const words = t.paragraphs.join(' ').split(/\s+/).length
  const part = (lang: string) => trans.map((x) => x[lang]).filter(Boolean)

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-[18px]">
      <div className="grid gap-5 xl:grid-cols-[minmax(280px,460px)_1fr]">
        <div className="flex flex-col gap-2.5">
          <DropZone plain multiple={false} onFiles={([f]) => upload.mutate(f)} className="grid aspect-[3/2] place-items-center overflow-hidden p-0">
            {data.cover ? (
              <img src={`/cover/${id}.jpg?v=${bust}`} alt={`Cover of ${t.title}`} className="size-full object-cover" />
            ) : (
              <div className="px-6 text-center text-muted">
                <ImageOff className="mx-auto mb-2 size-7" aria-hidden />
                No cover yet. Drop a picture, paste it (Ctrl+V) or click to choose.
              </div>
            )}
          </DropZone>
          <div className="flex flex-wrap items-center gap-3 text-xs text-muted">
            <label className="flex items-center gap-1.5"><input type="checkbox" checked={crop} onChange={(e) => setCrop(e.target.checked)} />cut a caption strip at the top (8 %)</label>
            {data.cover && (
              <Button size="sm" variant="ghost" onClick={async () => { if (confirm('Remove this cover?')) { await api.removeCover(id); toast('Cover removed'); await refresh() } }}>
                <Trash2 />Remove
              </Button>
            )}
          </div>
          <Card className="px-4 py-3">
            <div className="mb-1 flex items-center justify-between">
              <span className="text-xs font-semibold tracking-wider text-muted uppercase">Image prompt</span>
              <Button size="sm" variant="ghost" onClick={() => navigator.clipboard.writeText(data.prompt).then(() => toast('Prompt copied'))}><ClipboardCopy />Copy</Button>
            </div>
            <div className="max-h-[120px] overflow-auto text-xs whitespace-pre-wrap text-muted">{data.prompt}</div>
          </Card>
        </div>

        <div className="flex flex-col gap-3">
          <div>
            <div className="text-[13px] text-muted">{t.id} · {data.level}{t.topic ? ` · ${t.topic}` : ''} · {words} words</div>
            <h2 className="m-0 text-2xl font-bold tracking-tight"><Editable value={t.title} target={at('title')} refresh={editRefresh} /></h2>
          </div>
          {data.issues.length ? (
            <ul className="m-0 flex flex-col gap-1 rounded-xl bg-bad-soft py-2.5 pr-3 pl-7 text-[13px] text-bad-ink">
              {data.issues.map((i) => <li key={i}>{i}</li>)}
            </ul>
          ) : (
            <div className="text-[13px] text-ok">No automatic issues found.</div>
          )}
          <div className="flex flex-wrap items-center gap-2">
            <Button className="bg-ok text-white hover:opacity-90" disabled={review.isPending} onClick={() => review.mutate('ok')}><Check />Approve <kbd className="text-xs opacity-70">A</kbd></Button>
            <Button variant="gold" disabled={review.isPending} onClick={() => review.mutate('fix')}><Wrench />Needs a fix <kbd className="text-xs opacity-70">F</kbd></Button>
            <Button variant="ghost" disabled={review.isPending} onClick={() => review.mutate('')}><X />Clear</Button>
            <span className="text-xs text-muted">
              {data.review.status ? `${data.review.status === 'ok' ? 'Approved' : 'To fix'} · ${data.review.at}` : 'Not reviewed'}
            </span>
          </div>
          <label className="sr-only" htmlFor="note">Note</label>
          <textarea
            id="note"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="Note: what to fix (for ChatGPT or for Claude)"
            className="min-h-[64px] rounded-[10px] border border-line bg-surface px-3 py-2"
          />
          <div className="text-xs text-muted">← → or J K: previous / next text · A approve · F needs a fix · Ctrl+V paste a cover</div>
        </div>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Deutsch</h3>
          {t.paragraphs.map((p, i) => (
            <p key={i} className="group/p mt-0 mb-2.5 leading-relaxed">
              <Marked text={p} glossary={t.glossary} />
              <span className="block opacity-0 transition-opacity group-hover/p:opacity-100 focus-within:opacity-100">
                <Editable multiline className="text-xs text-muted" value={p} target={at(`paragraphs.${i}`)} refresh={editRefresh} placeholder="edit paragraph" />
              </span>
            </p>
          ))}
        </Card>
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Türkçe</h3>
          {trans.map((x, i) => x.tr ? <p key={i} className="mt-0 mb-2.5 leading-relaxed"><Editable multiline value={x.tr} target={at(`trans.${i}.tr`)} refresh={editRefresh} /></p> : null)}
          {!part('tr').length && <p className="text-bad">—</p>}
        </Card>
        <Card className="px-4 py-3.5">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">{langName(second)}{second !== 'en' && !part(second).length ? ' · not translated yet' : ''}</h3>
          {trans.map((x, i) => (x.en || x[second]) ? (
            <p key={i} className="mt-0 mb-2.5 leading-relaxed">
              <Editable multiline dir={langDir(second)} value={x[second] || ''} placeholder={second === 'en' ? 'empty' : `not translated · English: ${x.en}`} target={at(`trans.${i}.${second}`)} refresh={editRefresh} />
            </p>
          ) : null)}
          {!part(second).length && second === 'en' && <p className="text-bad">—</p>}
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="overflow-hidden">
          <h3 className="m-0 px-4 pt-3.5 pb-2 text-xs font-semibold tracking-wider text-muted uppercase">Glossary · {t.glossary.length}</h3>
          <table className="w-full border-collapse text-[13px]">
            <tbody>
              {t.glossary.map((g, i) => (
                <tr key={g.lemma + g.form} className="border-t border-line-soft">
                  <td className="px-4 py-1.5 font-semibold whitespace-nowrap">{g.art ? `${g.art} ` : ''}{g.lemma}</td>
                  <td className="px-2 py-1.5"><Editable value={g.mean.tr} target={at(`glossary.${i}.mean.tr`)} refresh={editRefresh} /></td>
                  <td className="px-4 py-1.5 text-muted">{g.mean.en ? <Editable dir={langDir(second)} value={g.mean[second] || ''} placeholder="not translated" target={at(`glossary.${i}.mean.${second}`)} refresh={editRefresh} /> : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
        <Card className="px-4 py-3.5 lg:col-span-2">
          <h3 className="mt-0 mb-2 text-xs font-semibold tracking-wider text-muted uppercase">Questions · correct answer in green</h3>
          {t.questions.map((q, i) => (
            <div key={i} className="mb-3">
              <b>{i + 1}.</b> <Editable value={q.q} target={at(`questions.${i}.q`)} refresh={editRefresh} />
              <ol className="mt-1 mb-0 pl-6">
                {(q.type === 'tf' ? ['Richtig', 'Falsch'] : q.options).map((o, j) => (
                  <li key={j} className={cn(j === q.answer && 'font-semibold text-ok')}>{o}</li>
                ))}
              </ol>
            </div>
          ))}
        </Card>
      </div>
    </div>
  )
}

export function Texts() {
  const { id } = useParams()
  const navigate = useNavigate()
  const toast = useToast()
  const client = useQueryClient()
  const [params, setParams] = useSearchParams()
  const level = (params.get('level') || id?.slice(0, 2).toUpperCase() || 'A1')
  const filter = (params.get('filter') || 'all') as Filter
  const [bust, setBust] = useState(Date.now())

  const summary = useQuery({ queryKey: ['textSummary'], queryFn: api.textSummary })
  const list = useQuery({ queryKey: ['texts', level], queryFn: () => api.texts(level) })
  const rows = useMemo(() => (list.data || []).filter((t) => matches(t, filter)), [list.data, filter])

  const set = (next: Record<string, string>) => setParams({ level, filter, ...next }, { replace: true })
  const open = (textId: string) => navigate(`/texts/${textId}?level=${level}&filter=${filter}`)
  const step = (d: number) => {
    if (!rows.length) return
    const i = rows.findIndex((t) => t.id === id)
    const next = rows[Math.max(0, Math.min(rows.length - 1, i + d))]
    if (next) { open(next.id); document.getElementById(`row-${next.id}`)?.scrollIntoView({ block: 'nearest' }) }
  }

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName
      if (tag === 'TEXTAREA' || tag === 'INPUT' || tag === 'SELECT') return
      if (e.key === 'ArrowRight' || e.key === 'j') step(1)
      if (e.key === 'ArrowLeft' || e.key === 'k') step(-1)
    }
    document.addEventListener('keydown', key)
    return () => document.removeEventListener('keydown', key)
  })

  const saveTexts = useMutation({
    mutationFn: api.saveTexts,
    onSuccess: async (r) => { toast(r.message); await client.invalidateQueries({ queryKey: ['textSummary'] }) },
  })
  const copyPrompts = async () => {
    const r = await api.coverPrompts(level)
    await navigator.clipboard.writeText(r.text)
    toast(`${r.count} prompts for ${level} copied`)
  }

  const changes = summary.data?.changes || 0
  return (
    <>
      <PageHeader
        title="Daily texts"
        description="Review texts, translations, glossary and questions; add the cover pictures."
        actions={<>
          <Button onClick={() => copyPrompts().catch((e) => toast(e.message))}><ClipboardCopy />Prompts for missing covers</Button>
          <Button variant="primary" disabled={!changes || saveTexts.isPending} onClick={() => saveTexts.mutate()}><Save />{changes ? `Save (${changes})` : 'Saved'}</Button>
        </>}
      />
      <div className="mb-4 flex flex-wrap gap-2">
        {(summary.data?.levels || []).map((l) => (
          <button
            key={l.level}
            type="button"
            onClick={() => { setParams({ level: l.level, filter }, { replace: true }); navigate(`/texts?level=${l.level}&filter=${filter}`) }}
            className={cn('rounded-xl border px-3.5 py-2 text-left', l.level === level ? 'border-ink bg-ink text-ground' : 'border-line bg-surface')}
          >
            <div className="font-bold">{l.level}</div>
            <div className={cn('text-xs', l.level === level ? 'opacity-75' : 'text-muted')}>{l.covers}/{l.texts} covers · {l.ok} ok{l.fix ? ` · ${l.fix} fix` : ''}</div>
          </button>
        ))}
      </div>
      <div className="flex flex-wrap items-start gap-5 lg:flex-nowrap">
        <aside aria-label="Texts" className="w-full shrink-0 overflow-hidden rounded-2xl border border-line bg-surface lg:sticky lg:top-6 lg:w-[340px]">
          <div className="flex flex-wrap gap-1.5 border-b border-line-soft p-3">
            {FILTERS.map(([key, label]) => (
              <button
                key={key}
                type="button"
                onClick={() => set({ filter: key })}
                className={cn('rounded-full border px-2.5 py-0.5 text-xs', filter === key ? 'border-blue bg-blue font-semibold text-white' : 'border-line bg-chip')}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="max-h-[70vh] overflow-auto">
            {list.isLoading && <Loading />}
            {rows.map((t) => (
              <button
                key={t.id}
                id={`row-${t.id}`}
                type="button"
                onClick={() => open(t.id)}
                className={cn('grid w-full grid-cols-[72px_1fr] gap-2.5 border-b border-line-soft px-3 py-2 text-left', t.id === id ? 'bg-gold-soft' : 'hover:bg-chip')}
              >
                {t.cover ? (
                  <img loading="lazy" src={`/cover/${t.id}.jpg?v=${bust}`} alt="" className="h-12 w-[72px] rounded-md object-cover" />
                ) : (
                  <div className="grid h-12 w-[72px] place-items-center rounded-md bg-chip text-[11px] text-muted">no cover</div>
                )}
                <div className="min-w-0">
                  <div className="truncate font-semibold">{t.title}</div>
                  <div className="flex flex-wrap items-center gap-1.5 text-xs text-muted">
                    <StatusDot status={t.review.status} />{t.id} · {t.topic}
                    {t.issues.length > 0 && <Badge tone="bad" className="px-1.5 py-0">{t.issues.length}</Badge>}
                  </div>
                </div>
              </button>
            ))}
            {!list.isLoading && !rows.length && <div className="p-8 text-center text-muted">Nothing here.</div>}
          </div>
        </aside>
        {id ? (
          <Detail
            key={id}
            id={id}
            bust={bust}
            onBust={() => setBust(Date.now())}
            onReviewed={(status) => { if (status === 'ok') step(1) }}
          />
        ) : (
          <div className="flex-1 py-16 text-center text-muted">Choose a text on the left. ← → move between texts.</div>
        )}
      </div>
    </>
  )
}
