import { cva, type VariantProps } from 'class-variance-authority'
import type { HTMLAttributes } from 'react'
import { cn } from '@/lib/utils'

const badgeVariants = cva('inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap', {
  variants: {
    tone: {
      neutral: 'bg-chip text-ink-soft',
      ok: 'bg-ok-soft text-ok-ink',
      bad: 'bg-bad-soft text-bad-ink',
      gold: 'bg-gold text-on-gold',
      level: 'rounded-md bg-gold px-2 text-on-gold font-bold',
    },
  },
  defaultVariants: { tone: 'neutral' },
})

type Props = HTMLAttributes<HTMLSpanElement> & VariantProps<typeof badgeVariants>

export function Badge({ className, tone, ...props }: Props) {
  return <span className={cn(badgeVariants({ tone }), className)} {...props} />
}
