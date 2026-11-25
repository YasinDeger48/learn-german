import { cva, type VariantProps } from 'class-variance-authority'
import type { ButtonHTMLAttributes } from 'react'
import { cn } from '@/lib/utils'

export const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 rounded-[10px] font-semibold whitespace-nowrap transition-colors cursor-pointer disabled:cursor-default disabled:opacity-45 [&_svg]:size-4 [&_svg]:shrink-0',
  {
    variants: {
      variant: {
        primary: 'bg-ink text-ground hover:opacity-90',
        gold: 'bg-gold text-on-gold font-bold hover:brightness-95',
        outline: 'border border-line bg-surface text-ink hover:bg-chip',
        ghost: 'text-ink hover:bg-chip',
        danger: 'bg-bad text-white hover:opacity-90',
      },
      size: {
        sm: 'h-8 px-3 text-xs',
        md: 'h-10 px-4 text-sm',
        icon: 'size-9',
      },
    },
    defaultVariants: { variant: 'outline', size: 'md' },
  },
)

type Props = ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof buttonVariants>

export function Button({ className, variant, size, type = 'button', ...props }: Props) {
  return <button type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />
}
