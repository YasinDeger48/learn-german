import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Check, Pencil, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useToast } from '@/components/ui/toast'
import { api, type EditTarget } from '@/lib/api'
import { cn } from '@/lib/utils'

/**
 * A text from a content file that can be changed in place: hover → pencil, Ctrl+Enter saves, Esc cancels.
 * The edit is written to the file and recorded in tools/content_edits.json (so it survives regenerated files).
 */
export function Editable({ value, target, refresh, className, multiline, dir, placeholder }: {
  value: string
  target: EditTarget
  /** Query keys to reload after saving. */
  refresh: string[]
  className?: string
  multiline?: boolean
  dir?: 'rtl' | 'ltr'
  placeholder?: string
}) {
  const toast = useToast()
  const client = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(value)
  const box = useRef<HTMLTextAreaElement>(null)
  useEffect(() => { if (!editing) setDraft(value) }, [value, editing])
  useEffect(() => {
    if (editing && box.current) {
      box.current.focus()
      box.current.style.height = `${box.current.scrollHeight + 2}px`
    }
  }, [editing])

  const save = useMutation({
    mutationFn: () => api.edit({ ...target, value: draft }),
    onSuccess: async () => {
      setEditing(false)
      toast('Saved · Publish to send it to the apps')
      await Promise.all([...refresh, 'overview', 'changes', 'edits'].map((key) => client.invalidateQueries({ queryKey: [key] })))
    },
    onError: (e) => toast(`Not saved: ${(e as Error).message}`),
  })

  if (!editing) {
    return (
      <span className={cn('group/edit relative', className)} dir={dir}>
        {value || <span className="text-muted italic">{placeholder || 'empty'}</span>}
        <button
          type="button"
          aria-label="Edit"
          onClick={(e) => { e.stopPropagation(); setEditing(true) }}
          className="ml-1 inline-grid size-6 place-items-center rounded-md align-middle text-muted opacity-0 transition-opacity group-hover/edit:opacity-100 hover:bg-chip hover:text-ink focus:opacity-100"
        >
          <Pencil className="size-3.5" aria-hidden />
        </button>
      </span>
    )
  }
  return (
    <span className="flex w-full flex-col gap-1.5" onClick={(e) => e.stopPropagation()}>
      <textarea
        ref={box}
        value={draft}
        dir={dir}
        rows={multiline ? 3 : 1}
        onChange={(e) => { setDraft(e.target.value); e.target.style.height = 'auto'; e.target.style.height = `${e.target.scrollHeight + 2}px` }}
        onKeyDown={(e) => {
          if (e.key === 'Escape') { setEditing(false); setDraft(value) }
          if (e.key === 'Enter' && (e.ctrlKey || e.metaKey || !multiline)) { e.preventDefault(); if (draft.trim()) save.mutate() }
        }}
        className="w-full resize-none rounded-lg border border-blue bg-surface px-2 py-1 text-[inherit] leading-snug font-[inherit] outline-0"
      />
      <span className="flex items-center gap-1.5 text-xs">
        <button type="button" disabled={!draft.trim() || save.isPending} onClick={() => save.mutate()}
          className="inline-flex items-center gap-1 rounded-md bg-ink px-2 py-1 font-semibold text-ground disabled:opacity-50">
          <Check className="size-3.5" aria-hidden />{save.isPending ? 'Saving…' : 'Save'}
        </button>
        <button type="button" onClick={() => { setEditing(false); setDraft(value) }} className="inline-flex items-center gap-1 rounded-md px-2 py-1 hover:bg-chip">
          <X className="size-3.5" aria-hidden />Cancel
        </button>
        <span className="text-muted">{multiline ? 'Ctrl+Enter' : 'Enter'} saves · Esc cancels</span>
      </span>
    </span>
  )
}
