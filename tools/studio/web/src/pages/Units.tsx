import { useQuery, useQueryClient } from '@tanstack/react-query'
import { BookOpen, FileText, Mic, PenLine, Quote, Type, type LucideIcon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { AddForm, AddedMark } from '@/components/ui/add-form'
import { Badge } from '@/components/ui/badge'
import { Card } from '@/components/ui/card'
import { DropZone } from '@/components/ui/drop-zone'
import { Editable } from '@/components/ui/editable'
import { useToast } from '@/components/ui/toast'
import { api, type UnitFull } from '@/lib/api'
import { cn } from '@/lib/utils'

const LEVELS = ['A1', 'A2', 'B1', 'B2']
const ARTICLE: Record<string, string> = { der: 'text-[#2F5BEA]', die: 'text-[#C8323A]', das: 'text-[#157A41]' }

function Step({ n, icon: Icon, title, sub, children }: { n: number; icon: LucideIcon; title: string; sub?: string; children: ReactNode }) {
  return (
    <Card className="overflow-hidden">
      <div className="flex items-center gap-3 border-b border-line-soft px-[18px] py-3">
        <span className="grid size-8 shrink-0 place-items-center rounded-full bg-chip text-ink-soft"><Icon className="size-4" aria-hidden /></span>
        <div className="min-w-0 flex-1">
          <div className="font-bold">{n} · {title}</div>
          {sub && <div className="truncate text-xs text-muted">{sub}</div>}
        </div>
      </div>
      <div className="px-[18px] py-3.5">{children}</div>
    </Card>
  )
}

function Detail({ unit, bust, onBust }: { unit: UnitFull; bust: number; onBust: () => void }) {
  const toast = useToast()
  const client = useQueryClient()
  const pictures = unit.words.filter((w) => w.picture).length
  const at = (path: string) => ({ file: 'units.json', collection: 'units', keyField: 'id', key: unit.id, path })
  const refresh = ['units']

  const upload = async (file: File) => {
    try {
      // The backend routes a picture by its name, so give it the unit's cover name.
      const named = new File([file], `${unit.cover}.${file.name.split('.').pop() || 'jpg'}`, { type: file.type })
      const r = await api.picture(named)
      toast(r.message)
      onBust()
      await Promise.all(['units', 'inbox', 'overview'].map((key) => client.invalidateQueries({ queryKey: [key] })))
    } catch (e) {
      toast((e as Error).message)
    }
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="grid gap-5 xl:grid-cols-[minmax(280px,440px)_1fr]">
        <DropZone plain multiple={false} onFiles={([f]) => upload(f)} className="grid aspect-[3/2] place-items-center overflow-hidden p-0">
          {unit.hasCover ? (
            <img src={`/img/${unit.cover}.jpg?v=${bust}`} alt={`Picture of unit ${unit.number}`} className="size-full object-cover" />
          ) : (
            <div className="px-6 text-center text-muted">
              <div className="font-semibold text-ink">{unit.cover}.jpg missing</div>
              Drop ChatGPT's unit picture here (any file name).
            </div>
          )}
        </DropZone>
        <div className="flex flex-col gap-2">
          <div className="text-[13px] text-muted">{unit.level} · Unit {unit.number} · {unit.id}</div>
          <h2 className="m-0 text-2xl font-bold tracking-tight"><Editable value={unit.title.tr} target={at('title.tr')} refresh={refresh} /></h2>
          <div className="text-muted"><Editable value={unit.title.en} target={at('title.en')} refresh={refresh} /></div>
          <div className="mt-2 rounded-xl bg-gold-soft px-3.5 py-2.5"><b>Goal:</b> <Editable value={unit.goal.tr} target={at('goal.tr')} refresh={refresh} /><div className="text-xs text-muted"><Editable value={unit.goal.en} target={at('goal.en')} refresh={refresh} /></div></div>
          <div className="mt-1 flex flex-wrap gap-1.5">
            <Badge>{unit.words.length} words</Badge>
            <Badge>{unit.phrases.length} phrases</Badge>
            <Badge>{unit.grammar.length} grammar</Badge>
            <Badge>{unit.texts.length} texts</Badge>
            {unit.level === 'A1' && <Badge tone={pictures === unit.words.length ? 'ok' : 'neutral'}>word cards {pictures}/{unit.words.length}</Badge>}
          </div>
          <div className="mt-auto text-xs text-muted">Hover a text and click the pencil to change it. Edits are kept in <code>tools/content_edits.json</code>, so they survive when <code>tools/units.py</code> runs again.</div>
        </div>
      </div>

      <Step n={1} icon={Type} title="Words" sub={unit.themes.length ? unit.themes.join(' · ') : 'from the glossaries of the unit texts'}>
        <div className="grid grid-cols-[repeat(auto-fill,minmax(110px,1fr))] gap-2.5">
          {unit.words.map((w) => (
            <figure key={w.de} className="m-0 text-center">
              {w.picture ? (
                <img loading="lazy" src={`/img/${w.picture}.jpg?v=${bust}`} alt="" className="aspect-square w-full rounded-lg object-cover" />
              ) : (
                <div className={cn('grid aspect-square w-full place-items-center rounded-lg bg-chip text-2xl font-extrabold', ARTICLE[w.article || ''] || 'text-muted')}>{w.de.slice(0, 1)}</div>
              )}
              <figcaption className="mt-1 text-xs">
                <div className="truncate font-semibold">{w.article && <span className={ARTICLE[w.article]}>{w.article} </span>}{w.de}</div>
                <div className="truncate text-muted">{w.meaning}</div>
              </figcaption>
            </figure>
          ))}
        </div>
      </Step>

      <Step n={2} icon={Quote} title="Phrases">
        <ul className="m-0 flex list-none flex-col gap-2 p-0">
          {unit.phrases.map((p, i) => (
            <li key={i} className="grid gap-0.5 rounded-lg border border-line-soft px-3 py-2">
              <span><Editable className="font-semibold" value={p.de} target={at(`phrases.${i}.de`)} refresh={refresh} />{p.added && <AddedMark refresh={refresh} remove={{ file: 'units.json', collection: 'units', item: { de: p.de }, parent: { keyField: 'id', key: unit.id, path: 'phrases' } }} />}</span>
              <Editable className="text-xs text-muted" value={p.tr} target={at(`phrases.${i}.tr`)} refresh={refresh} />
              <Editable className="text-xs text-muted" value={p.en} target={at(`phrases.${i}.en`)} refresh={refresh} />
            </li>
          ))}
        </ul>
        <div className="mt-3">
          <AddForm
            kind="phrase"
            file="units.json"
            label="Add a phrase"
            refresh={refresh}
            extra={{ unit: unit.id }}
            fields={[
              { name: 'de', label: 'German', placeholder: 'Eine Laugenstange, bitte.', wide: true },
              { name: 'tr', label: 'Türkçe' },
              { name: 'en', label: 'English' },
            ]}
          />
        </div>
      </Step>

      <Step n={3} icon={BookOpen} title="Grammar">
        <div className="flex flex-col gap-1.5">
          {unit.grammar.map((g) => <div key={g.id}><b>{g.de}</b> <span className="text-muted">· {g.name}</span></div>)}
        </div>
      </Step>

      <Step n={4} icon={FileText} title="Read and listen" sub="the learner gets the first text not finished">
        <div className="grid grid-cols-[repeat(auto-fill,minmax(170px,1fr))] gap-2.5">
          {unit.texts.map((t) => (
            <Link key={t.id} to={`/texts/${t.id}?level=${unit.level}`} className="overflow-hidden rounded-xl border border-line text-ink no-underline hover:border-muted">
              {t.cover ? <img loading="lazy" src={`/cover/${t.id}.jpg`} alt="" className="aspect-[3/2] w-full object-cover" /> : <div className="grid aspect-[3/2] place-items-center bg-chip text-xs text-muted">no cover</div>}
              <div className="px-2.5 py-1.5"><div className="truncate text-[13px] font-semibold">{t.title}</div><div className="text-xs text-muted">{t.id}</div></div>
            </Link>
          ))}
        </div>
      </Step>

      <div className="grid gap-4 lg:grid-cols-2">
        <Step n={5} icon={Mic} title="Speak">
          {unit.speaking.map((t) => <div key={t.id}>{t.title} <span className="text-xs text-muted">· {t.id}</span></div>)}
          {!unit.speaking.length && <div className="text-muted">No speaking task.</div>}
        </Step>
        <Step n={6} icon={PenLine} title="Extra: writing">
          {unit.writing.map((t) => <div key={t.id}>{t.title} <span className="text-xs text-muted">· {t.id}</span></div>)}
          {!unit.writing.length && <div className="text-muted">No writing task.</div>}
        </Step>
      </div>
      <div className="text-xs text-muted">Then the unit test (words, grammar, phrases): 80 % opens the next unit.</div>
    </div>
  )
}

export function Units() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { data, error, isLoading } = useQuery({ queryKey: ['units'], queryFn: api.units })
  const [bust, setBust] = useState(Date.now())
  const current = data?.find((u) => u.id === id) || data?.[0]
  const level = current?.level || 'A1'

  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const list = data.filter((u) => u.level === level)

  return (
    <>
      <PageHeader title="Path units" description="The step-by-step path: every unit with its words, phrases, grammar, texts and tasks." />
      <div className="mb-4 flex flex-wrap gap-2">
        {LEVELS.map((l) => {
          const items = data.filter((u) => u.level === l)
          return (
            <button
              key={l}
              type="button"
              onClick={() => items[0] && navigate(`/units/${items[0].id}`)}
              className={cn('rounded-xl border px-3.5 py-2 text-left', l === level ? 'border-ink bg-ink text-ground' : 'border-line bg-surface')}
            >
              <div className="font-bold">{l}</div>
              <div className={cn('text-xs', l === level ? 'opacity-75' : 'text-muted')}>{items.length} units · {items.filter((u) => u.hasCover).length} pictures</div>
            </button>
          )
        })}
      </div>
      <div className="flex flex-wrap items-start gap-5 lg:flex-nowrap">
        <aside aria-label="Units" className="w-full shrink-0 overflow-hidden rounded-2xl border border-line bg-surface lg:sticky lg:top-6 lg:w-[320px]">
          {list.map((u) => (
            <button
              key={u.id}
              type="button"
              onClick={() => navigate(`/units/${u.id}`)}
              className={cn('grid w-full grid-cols-[64px_1fr] items-center gap-3 border-b border-line-soft px-3 py-2 text-left last:border-b-0', u.id === current?.id ? 'bg-gold-soft' : 'hover:bg-chip')}
            >
              {u.hasCover ? (
                <img src={`/img/${u.cover}.jpg?v=${bust}`} alt="" className="h-11 w-16 rounded-md object-cover" />
              ) : (
                <div className="grid h-11 w-16 place-items-center rounded-md bg-chip text-lg font-bold text-muted">{u.number}</div>
              )}
              <div className="min-w-0">
                <div className="truncate font-semibold">{u.number}. {u.title.tr}</div>
                <div className="truncate text-xs text-muted">{u.grammar.map((g) => g.de).join(' · ')}</div>
              </div>
            </button>
          ))}
        </aside>
        {current && <Detail key={current.id} unit={current} bust={bust} onBust={() => setBust(Date.now())} />}
      </div>
    </>
  )
}
