import { cn } from '@/lib/utils'

/** A thin bar; `value` 0–100. */
export function Progress({ value, className, tone = 'ok' }: { value: number; className?: string; tone?: 'ok' | 'gold' | 'blue' }) {
  const fill = { ok: 'bg-ok', gold: 'bg-gold', blue: 'bg-blue' }[tone]
  const clamped = Math.max(0, Math.min(100, value))
  return (
    <div
      role="progressbar"
      aria-valuenow={clamped}
      aria-valuemin={0}
      aria-valuemax={100}
      className={cn('h-1.5 overflow-hidden rounded-full bg-chip', className)}
    >
      <div className={cn('h-full rounded-full transition-[width]', fill)} style={{ width: `${clamped}%` }} />
    </div>
  )
}
