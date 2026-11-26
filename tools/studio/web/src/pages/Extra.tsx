import { useQuery } from '@tanstack/react-query'
import { BookHeart, Music, Phone, Star, Voicemail } from 'lucide-react'
import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'
import { Editable } from '@/components/ui/editable'
import { LEVELS } from '@/components/ui/level-tabs'
import { api, type EditTarget, type ExtraKind, type ExtraList, type ExtraText, type Langs, type MustSheet, type Question, type Song } from '@/lib/api'
import { cn } from '@/lib/utils'

/**
 * The content the app has besides daily texts, words and grammar: phone calls and voicemail (tools/phone.py),
 * stories (tools/stories*.py), songs (tools/karaoke.py) and the "Mutlaka bil" sheets (tools/memorize.py).
 * Texts can be corrected in place (recorded in tools/content_edits.json like on the other pages).
 */
const KINDS: { key: ExtraKind; label: string; levels: string[] }[] = [
  { key: 'phone', label: 'Phone calls', levels: LEVELS },
  { key: 'stories', label: 'Stories', levels: LEVELS },
  { key: 'songs', label: 'Songs', levels: ['A1'] },
  { key: 'must', label: 'Must know', levels: ['A1'] },
]

type Target = (key: string | number, path: string) => EditTarget

function targetOf<T>(list: ExtraList<T>): Target {
  return (key, path) => ({ file: list.file, collection: list.collection, keyField: list.keyField, key, path })
}

function Questions({ questions, target, refresh }: { questions: Question[]; target: (path: string) => EditTarget; refresh: string[] }) {
  if (!questions?.length) return null
  return (
    <div>
      <h4 className="mt-0 mb-1.5 text-xs tracking-wider text-muted uppercase">Quiz · {questions.length}</h4>
      <ol className="m-0 flex flex-col gap-1.5 pl-5">
        {questions.map((q, i) => (
          <li key={i} className="text-[13px]">
            <Editable value={q.q} target={target(`questions.${i}.q`)} refresh={refresh} />
            <div className="text-xs text-muted">
              {q.type === 'tf'
                ? (q.answer === 0 ? '✓ richtig' : '✓ falsch')
                : (q.options || []).map((o, j) => <span key={j} className={cn('mr-2', j === q.answer && 'font-semibold text-ink')}>{j === q.answer ? '✓ ' : ''}{o}</span>)}
            </div>
          </li>
        ))}
      </ol>
    </div>
  )
}

function TextItem({ text, target, refresh }: { text: ExtraText; target: Target; refresh: string[] }) {
  const t = (path: string) => target(text.id, path)
  return (
    <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
      <div className="flex flex-col gap-2">
        {text.paragraphs.map((p, i) => (
          <div key={i} className="rounded-lg border border-line-soft px-3 py-2">
            <Editable value={p} target={t(`paragraphs.${i}`)} refresh={refresh} className="font-medium" />
            {text.trans?.[i] && (
              <div className="mt-1 flex flex-col gap-0.5 text-[13px] text-muted">
                {text.trans[i].tr !== undefined && <span>TR · <Editable value={text.trans[i].tr || ''} target={t(`trans.${i}.tr`)} refresh={refresh} /></span>}
                {text.trans[i].en !== undefined && <span>EN · <Editable value={text.trans[i].en || ''} target={t(`trans.${i}.en`)} refresh={refresh} /></span>}
              </div>
            )}
          </div>
        ))}
      </div>
      <div className="flex flex-col gap-4">
        <div>
          <h4 className="mt-0 mb-1.5 text-xs tracking-wider text-muted uppercase">Recording</h4>
          {text.audio.length ? text.audio.map((v) => (
            <div key={v} className="mb-1.5 flex items-center gap-2 text-xs">
              <span className="w-12 text-muted">{v === 'f' ? 'woman' : 'man'}</span>
              <audio controls preload="none" src={`/audio-extra/${v}/${text.id}.mp3`} className="h-8 flex-1" />
            </div>
          )) : <div className="text-xs text-muted">Not recorded yet: python -I -X utf8 tools/audio.py {text.level}{text.id.startsWith('t-') ? ' --phone-only' : ''}</div>}
          <div className="mt-1 text-[11px] text-muted">A corrected text is recorded again by tools/audio.py (it only makes the changed ones).</div>
        </div>
        <Questions questions={text.questions} target={t} refresh={refresh} />
      </div>
    </div>
  )
}

function SongItem({ song, target, refresh }: { song: Song; target: Target; refresh: string[] }) {
  const t = (path: string) => target(song.id, path)
  return (
    <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
      <div className="flex flex-col gap-1.5">
        {song.lines.map((line, i) => (
          <div key={i} className="rounded-lg border border-line-soft px-3 py-1.5">
            <div className="font-medium">{line.de}</div>
            <div className="flex flex-col gap-0.5 text-[13px] text-muted">
              <span>TR · <Editable value={line.tr} target={t(`lines.${i}.tr`)} refresh={refresh} /></span>
              <span>EN · <Editable value={line.en} target={t(`lines.${i}.en`)} refresh={refresh} /></span>
            </div>
          </div>
        ))}
        <div className="text-[11px] text-muted">The German lyrics, melody and syllable timings come from tools/karaoke.py (change them there).</div>
      </div>
      <div className="flex flex-col gap-4">
        <div>
          <h4 className="mt-0 mb-1.5 text-xs tracking-wider text-muted uppercase">Music · {song.bpm} bpm{song.duration ? ` · ${Math.round(song.duration)} s` : ''}</h4>
          {song.hasAudio ? <audio controls preload="none" src={`/audio-song/${song.id}.mp3`} className="h-8 w-full" />
            : <div className="text-xs text-muted">Not made yet: python -I -X utf8 tools/karaoke.py</div>}
        </div>
        <div className="text-[13px]">
          <div>TR · <Editable value={song.title_tr} target={t('title_tr')} refresh={refresh} /></div>
          <div>EN · <Editable value={song.title_en} target={t('title_en')} refresh={refresh} /></div>
        </div>
        <Questions questions={song.questions} target={t} refresh={refresh} />
      </div>
    </div>
  )
}

function MustItem({ sheet, target, refresh }: { sheet: MustSheet; target: Target; refresh: string[] }) {
  const t = (path: string) => target(sheet.id, path)
  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-xl bg-sunken px-3 py-2 text-[13px]">
        <div>TR · <Editable value={sheet.intro.tr} target={t('intro.tr')} refresh={refresh} /></div>
        {sheet.intro.en !== undefined && <div>EN · <Editable value={sheet.intro.en || ''} target={t('intro.en')} refresh={refresh} /></div>}
      </div>
      <table className="w-full border-collapse text-[13px]">
        <thead>
          <tr className="text-left text-xs text-muted">
            <th className="py-1 pr-3 font-medium">Asked</th><th className="py-1 pr-3 font-medium">Answer</th><th className="py-1 font-medium">Example · meaning</th>
          </tr>
        </thead>
        <tbody>
          {sheet.rows.map((row, i) => (
            <tr key={i} className="border-t border-line-soft align-top">
              <td className="py-1.5 pr-3">
                {typeof row.q === 'string'
                  ? <Editable value={row.q} target={t(`rows.${i}.q`)} refresh={refresh} />
                  : <>
                      <Editable value={(row.q as Langs).tr} target={t(`rows.${i}.q.tr`)} refresh={refresh} />
                      {(row.q as Langs).en !== undefined && <div className="text-xs text-muted"><Editable value={(row.q as Langs).en || ''} target={t(`rows.${i}.q.en`)} refresh={refresh} /></div>}
                    </>}
              </td>
              <td className="py-1.5 pr-3 font-semibold"><Editable value={row.a} target={t(`rows.${i}.a`)} refresh={refresh} /></td>
              <td className="py-1.5">
                {row.x !== undefined && <div className="italic"><Editable value={row.x} target={t(`rows.${i}.x`)} refresh={refresh} /></div>}
                {row.xm && (
                  <div className="text-xs text-muted">
                    <div>TR · <Editable value={row.xm.tr} target={t(`rows.${i}.xm.tr`)} refresh={refresh} /></div>
                    {row.xm.en !== undefined && <div>EN · <Editable value={row.xm.en || ''} target={t(`rows.${i}.xm.en`)} refresh={refresh} /></div>}
                  </div>
                )}
                {row.x !== undefined && !row.xm && <Badge className="mt-0.5 font-normal">no meaning yet</Badge>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function Extra() {
  const [params, setParams] = useSearchParams()
  const kind = (params.get('kind') || 'phone') as ExtraKind
  const info = KINDS.find((k) => k.key === kind) || KINDS[0]
  const level = info.levels.includes(params.get('level') || '') ? params.get('level')! : info.levels[0]
  const [open, setOpen] = useState<string | null>(null)
  const queryKey = ['extra', kind, level]
  const { data, error, isLoading } = useQuery({ queryKey, queryFn: () => api.extra<ExtraText | Song | MustSheet>(kind, level) })
  const refresh = ['extra']
  const set = (next: Record<string, string>) => setParams({ kind, level, ...next }, { replace: true })

  return (
    <>
      <PageHeader title="More content" description="Phone calls, stories, songs and the Must know sheets: read, listen and correct the texts. Publish sends the changes to the apps." />
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div role="tablist" className="flex flex-wrap gap-1 rounded-xl bg-chip p-1">
          {KINDS.map((k) => (
            <button key={k.key} role="tab" type="button" aria-selected={kind === k.key} onClick={() => setParams({ kind: k.key, level: k.levels.includes(level) ? level : k.levels[0] }, { replace: true })}
              className={cn('rounded-lg px-3 py-1.5', kind === k.key ? 'bg-surface font-semibold shadow-sm' : 'text-ink-soft')}>
              {k.label}
            </button>
          ))}
        </div>
        <div className="flex gap-1.5">
          {info.levels.map((l) => (
            <button key={l} type="button" onClick={() => set({ level: l })}
              className={cn('rounded-full border px-3.5 py-1 text-[13px]', l === level ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}>
              {l}
            </button>
          ))}
        </div>
      </div>

      {isLoading && <Loading />}
      {error && <Failed error={error} />}
      {data && (
        <div className="flex flex-col gap-3">
          {data.items.map((item) => {
            const id = (item as { id: string }).id
            const isOpen = open === id
            const target = targetOf(data)
            let Icon = Phone
            let title = ''
            let sub = ''
            let meta = ''
            if (kind === 'phone' || kind === 'stories') {
              const text = item as ExtraText
              Icon = kind === 'stories' ? BookHeart : text.topic === 'message' ? Voicemail : Phone
              title = text.title
              sub = `${text.id} · ${kind === 'phone' ? (text.topic === 'message' ? 'voicemail' : 'call') : text.topic}`
              meta = `${text.paragraphs.length} lines · ${text.questions?.length || 0} questions · ${text.audio.length ? 'recorded' : 'no audio'}`
            } else if (kind === 'songs') {
              const song = item as Song
              Icon = Music
              title = song.title
              sub = `${song.title_tr} · ${song.id}`
              meta = `${song.lines.length} lines · ${song.hasAudio ? 'music ready' : 'no music'}`
            } else {
              const sheet = item as MustSheet
              Icon = Star
              title = sheet.title.tr
              sub = `${sheet.title.en || ''} · ${sheet.id}`
              const examples = sheet.rows.filter((r) => r.x !== undefined)
              meta = `${sheet.rows.length} rows${examples.length ? ` · ${examples.filter((r) => r.xm).length}/${examples.length} meanings` : ''}`
            }
            return (
              <Card key={id} className="overflow-hidden">
                <button type="button" onClick={() => setOpen(isOpen ? null : id)} className="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-chip">
                  <span className="grid size-8 shrink-0 place-items-center rounded-full bg-chip text-ink-soft"><Icon className="size-4" aria-hidden /></span>
                  <span className="min-w-0 flex-1">
                    <span className="block font-semibold">{title}</span>
                    <span className="block text-xs text-muted">{sub}</span>
                  </span>
                  <span className="text-xs text-muted">{meta}</span>
                </button>
                {isOpen && (
                  <div className="border-t border-line-soft px-4 py-3.5">
                    {(kind === 'phone' || kind === 'stories') && <TextItem text={item as ExtraText} target={target} refresh={refresh} />}
                    {kind === 'songs' && <SongItem song={item as Song} target={target} refresh={refresh} />}
                    {kind === 'must' && <MustItem sheet={item as MustSheet} target={target} refresh={refresh} />}
                  </div>
                )}
              </Card>
            )
          })}
          {!data.items.length && <div className="py-10 text-center text-muted">Nothing here for {level} yet.</div>}
        </div>
      )}
    </>
  )
}
