import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Pause, Play } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardHeader } from '@/components/ui/card'
import { DropZone } from '@/components/ui/drop-zone'
import { useToast } from '@/components/ui/toast'
import { api } from '@/lib/api'
import { cn, fmt } from '@/lib/utils'

const TABS = [
  ['covers', 'Text covers'],
  ['units', 'Unit pictures'],
  ['cards', 'Word cards'],
  ['audio', 'Audio'],
] as const
type Tab = (typeof TABS)[number][0]
const LEVELS = ['A1', 'A2', 'B1', 'B2']

function Placeholder({ label, className }: { label: string; className?: string }) {
  return (
    <div className={cn('grid place-items-center bg-[repeating-linear-gradient(135deg,var(--chip)_0_10px,var(--line-soft)_10px_20px)] px-2 text-center text-xs text-muted', className)}>
      {label}
    </div>
  )
}

function LevelChips({ level, setLevel, counts }: { level: string; setLevel: (l: string) => void; counts: Record<string, string> }) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {LEVELS.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLevel(l)}
          className={cn('rounded-full border px-3.5 py-1 text-[13px]', l === level ? 'border-ink bg-ink font-semibold text-ground' : 'border-line bg-surface')}
        >
          {l}{counts[l] ? ` · ${counts[l]}` : ''}
        </button>
      ))}
    </div>
  )
}

function Covers({ bust }: { bust: number }) {
  const [level, setLevel] = useState('A1')
  const { data, error, isLoading } = useQuery({ queryKey: ['covers'], queryFn: api.covers })
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const counts = Object.fromEntries(LEVELS.map((l) => {
    const items = data.filter((c) => c.level === l)
    return [l, `${items.filter((c) => c.cover).length}/${items.length}`]
  }))
  return (
    <div className="flex flex-col gap-4">
      <LevelChips level={level} setLevel={setLevel} counts={counts} />
      <div className="grid grid-cols-[repeat(auto-fill,minmax(180px,1fr))] gap-3">
        {data.filter((c) => c.level === level).map((c) => (
          <Link key={c.id} to={`/texts/${c.id}?level=${c.level}`} className="overflow-hidden rounded-xl border border-line bg-surface text-ink no-underline hover:border-muted">
            {c.cover ? <img loading="lazy" src={`/cover/${c.id}.jpg?v=${bust}`} alt="" className="aspect-[3/2] w-full object-cover" /> : <Placeholder label={`${c.id}.jpg missing`} className="aspect-[3/2]" />}
            <div className="px-2.5 py-2">
              <div className="truncate text-[13px] font-semibold">{c.title}</div>
              <div className="text-xs text-muted">{c.id}{c.review ? ` · ${c.review === 'ok' ? 'approved' : 'to fix'}` : ''}</div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}

function Units({ bust }: { bust: number }) {
  const [level, setLevel] = useState('A1')
  const { data, error, isLoading } = useQuery({ queryKey: ['inbox'], queryFn: api.inbox })
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const counts = Object.fromEntries(LEVELS.map((l) => {
    const items = data.units.filter((u) => u.level === l)
    return [l, `${items.filter((u) => u.hasCover).length}/${items.length}`]
  }))
  return (
    <div className="flex flex-col gap-4">
      <LevelChips level={level} setLevel={setLevel} counts={counts} />
      <div className="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-3.5">
        {data.units.filter((u) => u.level === level).map((u) => (
          <article key={u.id} className="overflow-hidden rounded-2xl border border-line bg-surface">
            {u.hasCover ? <img src={`/img/${u.cover}.jpg?v=${bust}`} alt="" className="aspect-[3/2] w-full object-cover" /> : <Placeholder label={`${u.cover}.jpg missing`} className="aspect-[3/2]" />}
            <div className="flex flex-col gap-1 px-3 py-2.5">
              <div className="font-semibold">{u.number}. {u.titleTr}</div>
              <div className="flex justify-between gap-2 text-xs text-muted">
                <span>{u.title}</span>
                {u.grid && <span>cards {u.gridDone}/{u.gridTotal}</span>}
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}

const ARTICLE = { der: 'text-[#2F5BEA]', die: 'text-[#C8323A]', das: 'text-[#157A41]' } as Record<string, string>

function Cards({ bust }: { bust: number }) {
  const { data, error, isLoading } = useQuery({ queryKey: ['wordcards'], queryFn: api.wordcards })
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  return (
    <div className="flex flex-col gap-4">
      <div className="text-[13px] text-muted">A1 for now: 16 picture words per unit. ChatGPT draws each unit as one 4×4 grid (<code>words-a1-NN.jpg</code>); dropping it here cuts it into the cards below.</div>
      {data.map((u) => {
        const done = u.cards.filter((c) => c.exists).length
        return (
          <Card key={u.unit} className="overflow-hidden">
            <CardHeader title={`${u.unit} · ${u.title}`} action={<Badge tone={done === u.cards.length ? 'ok' : done ? 'gold' : 'neutral'}>{done} / {u.cards.length}</Badge>} />
            <div className="grid grid-cols-4 gap-2.5 p-3.5 sm:grid-cols-8">
              {u.cards.map((c) => (
                <figure key={c.id} className="m-0">
                  {c.exists ? (
                    <img loading="lazy" src={`/img/${c.file}.jpg?v=${bust}`} alt={c.de} className="aspect-square w-full rounded-lg object-cover" />
                  ) : (
                    <div className={cn('grid aspect-square w-full place-items-center rounded-lg bg-chip text-2xl font-extrabold', ARTICLE[c.article || ''] || 'text-muted')}>{c.de.slice(0, 1)}</div>
                  )}
                  <figcaption className="mt-1 truncate text-center text-[11px]" title={c.meaning}>
                    {c.article && <span className={ARTICLE[c.article]}>{c.article} </span>}{c.de}
                  </figcaption>
                </figure>
              ))}
            </div>
          </Card>
        )
      })}
    </div>
  )
}

function AudioTab() {
  const { data, error, isLoading } = useQuery({ queryKey: ['audio'], queryFn: api.audio })
  const player = useRef<HTMLAudioElement | null>(null)
  const [playing, setPlaying] = useState('')
  const [level, setLevel] = useState('A1')
  useEffect(() => () => player.current?.pause(), [])
  const play = (src: string) => {
    player.current?.pause()
    if (playing === src) { setPlaying(''); return }
    const audio = new Audio(src)
    audio.onended = () => setPlaying('')
    audio.play().catch(() => setPlaying(''))
    player.current = audio
    setPlaying(src)
  }
  const PlayButton = ({ src, label }: { src: string; label: string }) => (
    <Button size="sm" variant={playing === src ? 'primary' : 'outline'} aria-label={`${playing === src ? 'Stop' : 'Play'} ${label}`} onClick={() => play(src)}>
      {playing === src ? <Pause /> : <Play />}{label}
    </Button>
  )
  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const c = data.counts
  const tiles = [
    ['Texts · Anna (female)', fmt(c.female), 'Chirp 3 HD'],
    ['Texts · Max (male)', fmt(c.male), 'Chirp 3 HD'],
    ['Word pronunciations', fmt(c.words), 'Neural2, with pauses'],
    ['Background sounds', fmt(c.ambience), 'CC0 from Freesound'],
  ]
  const counts = Object.fromEntries(LEVELS.map((l) => [l, String(data.texts.filter((t) => t.id.startsWith(l.toLowerCase())).length)]))
  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-[repeat(auto-fit,minmax(190px,1fr))] gap-3">
        {tiles.map(([label, value, note]) => (
          <div key={label} className="rounded-2xl border border-line bg-surface px-4 py-3">
            <div className="text-xs text-muted">{label}</div>
            <div className="text-2xl font-bold">{value}</div>
            <div className="text-xs text-muted">{note}</div>
          </div>
        ))}
      </div>
      <Card className="overflow-hidden">
        <CardHeader title="Background sounds" />
        <div className="grid grid-cols-[repeat(auto-fill,minmax(260px,1fr))] gap-2 p-3.5">
          {data.ambience.map((a) => (
            <div key={a.kind} className="flex items-center gap-3 rounded-xl border border-line-soft px-3 py-2">
              <PlayButton src={`/audio/ambience/${a.kind}.m4a`} label={a.kind} />
              <div className="min-w-0 text-xs text-muted"><div className="truncate">{a.name}</div><div>{a.by} · {a.license}</div></div>
            </div>
          ))}
        </div>
      </Card>
      <Card className="overflow-hidden">
        <CardHeader title="Reading voices" action={<LevelChips level={level} setLevel={setLevel} counts={counts} />} />
        <div className="max-h-[520px] overflow-auto">
          {data.texts.filter((t) => t.id.startsWith(level.toLowerCase())).map((t) => (
            <div key={t.id} className="flex flex-wrap items-center gap-2.5 border-t border-line-soft px-[18px] py-2 first:border-t-0">
              <span className="w-16 text-xs text-muted">{t.id}</span>
              <span className="min-w-[160px] flex-1 font-medium">{t.title}</span>
              {t.voices.includes('f') && <PlayButton src={`/audio/f/${t.id}.mp3`} label="Anna" />}
              {t.voices.includes('m') && <PlayButton src={`/audio/m/${t.id}.mp3`} label="Max" />}
            </div>
          ))}
          {!data.texts.some((t) => t.id.startsWith(level.toLowerCase())) && <div className="p-8 text-center text-muted">No recordings for {level} yet.</div>}
        </div>
      </Card>
    </div>
  )
}

export function Media() {
  const toast = useToast()
  const client = useQueryClient()
  const [params, setParams] = useSearchParams()
  const tab = (params.get('tab') || 'covers') as Tab
  const [bust, setBust] = useState(Date.now())
  const [lastGrid, setLastGrid] = useState<string[]>([])
  const [busy, setBusy] = useState(false)

  const upload = async (files: File[]) => {
    setBusy(true)
    let saved = 0
    for (const file of files) {
      try {
        const r = await api.picture(file)
        if (r.pictures.length > 1) setLastGrid(r.pictures)
        saved++
        toast(r.message)
      } catch (e) {
        toast((e as Error).message)
        await new Promise((resolve) => setTimeout(resolve, 1800))
      }
    }
    setBust(Date.now())
    setBusy(false)
    await Promise.all(['covers', 'inbox', 'wordcards', 'overview', 'textSummary', 'texts'].map((key) => client.invalidateQueries({ queryKey: [key] })))
    if (files.length > 1) toast(`${saved} of ${files.length} pictures saved`)
  }

  return (
    <>
      <PageHeader title="Media" description="Pictures and audio in one place. Drop files on the box: the file name decides where they go." />
      <div className="flex flex-col gap-4">
        <DropZone onFiles={upload}>
          <div className="font-semibold">{busy ? 'Saving…' : "Drop ChatGPT's pictures here, several at once"}</div>
          <div className="mt-0.5 text-[13px] text-muted">
            <code>unit-a1-03.jpg</code> unit picture · <code>words-a1-03.jpg</code> 4×4 grid → 16 word cards · <code>a2-014.jpg</code> text cover
          </div>
        </DropZone>
        {lastGrid.length > 0 && (
          <Card className="p-3.5">
            <div className="mb-2 text-[13px] font-semibold">Last word grid, cut into {lastGrid.length} cards</div>
            <div className="grid grid-cols-8 gap-2">
              {lastGrid.map((p) => <img key={p} src={`/img/${p}.jpg?v=${bust}`} alt={p} title={p} className="aspect-square w-full rounded-lg object-cover" />)}
            </div>
          </Card>
        )}
        <div role="tablist" aria-label="Media type" className="flex w-fit flex-wrap gap-1 rounded-xl bg-chip p-1">
          {TABS.map(([key, label]) => (
            <button
              key={key}
              role="tab"
              type="button"
              aria-selected={tab === key}
              onClick={() => setParams({ tab: key }, { replace: true })}
              className={cn('rounded-lg px-3 py-1.5', tab === key ? 'bg-surface font-semibold shadow-sm' : 'text-ink-soft')}
            >
              {label}
            </button>
          ))}
        </div>
        {tab === 'covers' && <Covers bust={bust} />}
        {tab === 'units' && <Units bust={bust} />}
        {tab === 'cards' && <Cards bust={bust} />}
        {tab === 'audio' && <AudioTab />}
      </div>
    </>
  )
}
