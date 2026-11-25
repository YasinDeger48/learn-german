import { Upload } from 'lucide-react'
import { useRef, useState, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

/** Drop files here, or click to choose. Calls `onFiles` with pictures only. */
export function DropZone({ onFiles, children, multiple = true, plain = false, className }: {
  onFiles: (files: File[]) => void
  children: ReactNode
  multiple?: boolean
  /** No upload icon: the children fill the box (e.g. a picture). */
  plain?: boolean
  className?: string
}) {
  const input = useRef<HTMLInputElement>(null)
  const [hover, setHover] = useState(false)
  const take = (list: FileList | null) => {
    const files = [...(list || [])].filter((f) => /^image\//.test(f.type))
    if (files.length) onFiles(multiple ? files : files.slice(0, 1))
  }
  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => input.current?.click()}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && input.current?.click()}
      onDragOver={(e) => { e.preventDefault(); setHover(true) }}
      onDragLeave={() => setHover(false)}
      onDrop={(e) => { e.preventDefault(); setHover(false); take(e.dataTransfer.files) }}
      className={cn(
        'flex cursor-pointer flex-wrap items-center gap-4 rounded-2xl border-2 border-dashed bg-surface p-5 transition-colors',
        hover ? 'border-blue bg-blue/5' : 'border-line hover:border-muted',
        className,
      )}
    >
      {plain ? children : (
        <>
          <div className="grid size-12 shrink-0 place-items-center rounded-xl bg-gold-soft text-on-gold">
            <Upload className="size-6" aria-hidden />
          </div>
          <div className="min-w-[240px] flex-1">{children}</div>
        </>
      )}
      <input
        ref={input}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        multiple={multiple}
        hidden
        onChange={(e) => { take(e.target.files); e.target.value = '' }}
      />
    </div>
  )
}
