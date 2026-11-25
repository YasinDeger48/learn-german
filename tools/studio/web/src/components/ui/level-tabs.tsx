import { cn } from '@/lib/utils'

export const LEVELS = ['A1', 'A2', 'B1', 'B2']

/** A1 · A2 · B1 · B2 switch, with an optional line under each level. */
export function LevelTabs({ level, onChange, notes = {} }: { level: string; onChange: (level: string) => void; notes?: Record<string, string> }) {
  return (
    <div className="mb-4 flex flex-wrap gap-2">
      {LEVELS.map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => onChange(l)}
          className={cn('rounded-xl border px-3.5 py-2 text-left', l === level ? 'border-ink bg-ink text-ground' : 'border-line bg-surface')}
        >
          <div className="font-bold">{l}</div>
          {notes[l] && <div className={cn('text-xs', l === level ? 'opacity-75' : 'text-muted')}>{notes[l]}</div>}
        </button>
      ))}
    </div>
  )
}
