import { useQuery } from '@tanstack/react-query'
import {
  BookOpen,
  FileText,
  Globe,
  Image,
  Inbox,
  LayoutDashboard,
  ListChecks,
  Map,
  PenLine,
  Rocket,
  Type,
  type LucideIcon,
} from 'lucide-react'
import { NavLink, Outlet } from 'react-router-dom'
import { api } from '@/lib/api'
import { cn, fmt } from '@/lib/utils'

type Item = { to: string; label: string; icon: LucideIcon; count?: string; badge?: boolean; soon?: boolean }

function NavItem({ item }: { item: Item }) {
  const Icon = item.icon
  return (
    <NavLink
      to={item.to}
      end={item.to === '/'}
      className={({ isActive }) =>
        cn(
          'flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-nav-ink no-underline transition-colors hover:bg-nav-active',
          isActive && 'bg-nav-active font-semibold text-white',
        )
      }
    >
      <Icon className="size-4 shrink-0 opacity-80" aria-hidden />
      <span className="flex-1 truncate">{item.label}</span>
      {item.badge && item.count ? (
        <span className="rounded-full bg-gold px-2 text-xs font-bold text-on-gold">{item.count}</span>
      ) : item.count ? (
        <span className="text-xs text-nav-muted">{item.count}</span>
      ) : item.soon ? (
        <span className="text-[10px] uppercase tracking-wider text-nav-muted">soon</span>
      ) : null}
    </NavLink>
  )
}

function Group({ title }: { title: string }) {
  return <div className="px-2.5 pt-4 pb-1.5 text-[11px] uppercase tracking-[.08em] text-nav-muted">{title}</div>
}

export function AppShell() {
  const { data } = useQuery({ queryKey: ['overview'], queryFn: api.overview })
  const texts = data?.levels.reduce((sum, l) => sum + l.texts, 0)
  const words = data?.levels.reduce((sum, l) => sum + l.words, 0)
  const grammar = data?.levels.reduce((sum, l) => sum + l.grammarItems, 0)
  const tasks = data?.levels.reduce((sum, l) => sum + l.writing + l.speaking, 0)

  const content: Item[] = [
    { to: '/texts', label: 'Daily texts', icon: FileText, count: texts ? fmt(texts) : undefined },
    { to: '/units', label: 'Path units', icon: Map, count: data ? String(data.units.total) : undefined },
    { to: '/words', label: 'Words', icon: Type, count: words ? fmt(words) : undefined },
    { to: '/grammar', label: 'Grammar', icon: BookOpen, count: grammar ? fmt(grammar) : undefined },
    { to: '/verbs', label: 'Verb lab', icon: ListChecks, count: data ? fmt(data.verbs.ready) : undefined },
    { to: '/tasks', label: 'Writing & speaking', icon: PenLine, count: tasks ? String(tasks) : undefined },
  ]
  const workflow: Item[] = [
    { to: '/inbox', label: 'ChatGPT inbox', icon: Inbox, count: data ? fmt(data.waiting) : undefined, badge: true },
    { to: '/media', label: 'Media', icon: Image, count: data ? fmt(data.audio.female + data.audio.male + data.audio.words + texts!) : undefined },
    { to: '/translations', label: 'Translations', icon: Globe, count: data ? `${data.languages.length} lang.` : undefined },
    { to: '/publish', label: 'Publish', icon: Rocket, count: data ? String(data.unsaved) : undefined, badge: !!data?.unsaved },
  ]

  return (
    <div className="flex min-h-full flex-wrap">
      <nav aria-label="Studio" className="flex w-full flex-col gap-0.5 bg-nav px-3.5 py-5 text-sm md:sticky md:top-0 md:h-screen md:w-[248px] md:overflow-y-auto">
        <div className="flex items-center gap-2.5 px-2 pb-4">
          <div className="grid size-[30px] place-items-center rounded-lg bg-gold font-bold text-on-gold">D</div>
          <div className="text-base font-bold text-white">
            deschly <span className="text-gold">studio</span>
          </div>
        </div>
        <NavItem item={{ to: '/', label: 'Overview', icon: LayoutDashboard }} />
        <Group title="Content" />
        {content.map((item) => (
          <NavItem key={item.to} item={item} />
        ))}
        <Group title="Workflow" />
        {workflow.map((item) => (
          <NavItem key={item.to} item={item} />
        ))}
        <div className="mt-auto border-t border-white/10 px-2.5 pt-3.5 text-xs leading-relaxed text-nav-muted">
          <div>{data ? (data.unsaved ? `${data.unsaved} unsaved file${data.unsaved > 1 ? 's' : ''}` : 'All changes saved') : '…'}</div>
          <div>
            <a href="/classic" className="text-nav-muted underline-offset-2 hover:underline">Classic Studio</a> ·{' '}
            <a href="/docs" className="text-nav-muted underline-offset-2 hover:underline">API</a>
          </div>
        </div>
      </nav>
      <main className="min-w-0 flex-1 basis-[640px] px-5 pt-6 pb-12 md:px-8">
        <Outlet />
      </main>
    </div>
  )
}
