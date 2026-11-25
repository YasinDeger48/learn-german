import type { ReactNode } from 'react'

export function PageHeader({ eyebrow, title, description, actions }: {
  eyebrow?: string
  title: string
  description?: ReactNode
  actions?: ReactNode
}) {
  return (
    <header className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div className="min-w-[240px] flex-1">
        {eyebrow && <div className="text-[13px] text-muted">{eyebrow}</div>}
        <h1 className="m-0 text-[26px] font-bold tracking-tight">{title}</h1>
        {description && <div className="mt-1 text-muted">{description}</div>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </header>
  )
}

export function Loading({ what = 'Loading' }: { what?: string }) {
  return <div className="py-16 text-center text-muted">{what}…</div>
}

export function Failed({ error }: { error: unknown }) {
  return (
    <div className="rounded-xl border border-bad/30 bg-bad-soft px-4 py-3 text-bad-ink">
      Could not load: {error instanceof Error ? error.message : String(error)}. Is the Studio backend running?
    </div>
  )
}
