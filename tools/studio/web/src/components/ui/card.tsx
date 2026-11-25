import type { HTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'

export function Card({ className, ...props }: HTMLAttributes<HTMLElement>) {
  return <section className={cn('rounded-2xl border border-line bg-surface', className)} {...props} />
}

/** Title row of a card, with an optional action on the right. */
export function CardHeader({ title, action, className }: { title: ReactNode; action?: ReactNode; className?: string }) {
  return (
    <div className={cn('flex items-center justify-between gap-3 border-b border-line-soft px-[18px] py-3.5', className)}>
      <h2 className="m-0 text-[15px] font-bold">{title}</h2>
      {action}
    </div>
  )
}

export function CardBody({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('px-[18px] py-4', className)} {...props} />
}
