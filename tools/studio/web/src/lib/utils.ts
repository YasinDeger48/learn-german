import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/** Joins class names; later Tailwind classes win over earlier ones. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export const pad2 = (n: number) => String(n).padStart(2, '0')

export const fmt = (n: number) => n.toLocaleString('en-US')

export const percent = (part: number, whole: number) => (whole ? Math.round((100 * part) / whole) : 0)
