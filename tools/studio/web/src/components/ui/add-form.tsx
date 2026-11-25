import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2, X } from 'lucide-react'
import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { useToast } from '@/components/ui/toast'
import { api } from '@/lib/api'
import { cn } from '@/lib/utils'

export type FieldSpec = {
  name: string
  label: string
  placeholder?: string
  /** select options as [value, label] */
  options?: [string, string][]
  optional?: boolean
  wide?: boolean
  hint?: string
}

/**
 * "+ Add …" button that opens a small form; sends {kind, file, ...values} to /api/add.
 * The new item is recorded in tools/content_edits.json, so it survives regenerated files.
 */
export function AddForm({ kind, file, label, fields, extra, refresh, initial = {} }: {
  kind: 'word' | 'exercise' | 'phrase'
  file: string
  label: string
  fields: FieldSpec[]
  extra?: Record<string, unknown>
  refresh: string[]
  initial?: Record<string, string>
}) {
  const toast = useToast()
  const client = useQueryClient()
  const [open, setOpen] = useState(false)
  const [values, setValues] = useState<Record<string, string>>(initial)
  const add = useMutation({
    mutationFn: () => api.add({ kind, file, ...extra, ...values }),
    onSuccess: async () => {
      toast('Added · Publish to send it to the apps')
      setValues(initial)
      setOpen(false)
      await Promise.all([...refresh, 'overview', 'changes', 'edits'].map((key) => client.invalidateQueries({ queryKey: [key] })))
    },
    onError: (e) => toast(`Not added: ${(e as Error).message}`),
  })
  if (!open) {
    return <Button size="sm" variant="outline" onClick={() => setOpen(true)}><Plus />{label}</Button>
  }
  const missing = fields.some((f) => !f.optional && !(values[f.name] || '').trim())
  return (
    <form
      onSubmit={(e) => { e.preventDefault(); if (!missing) add.mutate() }}
      className="flex w-full flex-col gap-3 rounded-xl border border-blue/40 bg-blue/5 p-3.5"
    >
      <div className="flex items-center justify-between">
        <b>{label}</b>
        <button type="button" aria-label="Close" onClick={() => setOpen(false)} className="rounded-md p-1 hover:bg-chip"><X className="size-4" /></button>
      </div>
      <div className="grid gap-2.5 sm:grid-cols-2">
        {fields.map((f) => (
          <label key={f.name} className={cn('flex flex-col gap-1 text-xs font-semibold', f.wide && 'sm:col-span-2')}>
            <span>{f.label}{f.optional && <span className="font-normal text-muted"> · optional</span>}</span>
            {f.options ? (
              <select value={values[f.name] || ''} onChange={(e) => setValues({ ...values, [f.name]: e.target.value })}
                className="h-9 rounded-lg border border-line bg-surface px-2 text-sm font-normal">
                <option value="" disabled>Choose…</option>
                {f.options.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            ) : (
              <input value={values[f.name] || ''} placeholder={f.placeholder} onChange={(e) => setValues({ ...values, [f.name]: e.target.value })}
                className="h-9 rounded-lg border border-line bg-surface px-2.5 text-sm font-normal" />
            )}
            {f.hint && <span className="font-normal text-muted">{f.hint}</span>}
          </label>
        ))}
      </div>
      <div className="flex items-center gap-2">
        <Button type="submit" size="sm" variant="primary" disabled={missing || add.isPending}>{add.isPending ? 'Adding…' : 'Add'}</Button>
        <span className="text-xs text-muted">Kept in tools/content_edits.json · can be removed again</span>
      </div>
    </form>
  )
}

/** "new" badge plus a remove button for items added in the Studio. */
export function AddedMark({ remove, refresh }: { remove: Parameters<typeof api.remove>[0]; refresh: string[] }) {
  const toast = useToast()
  const client = useQueryClient()
  const run = useMutation({
    mutationFn: () => api.remove(remove),
    onSuccess: async () => {
      toast('Removed')
      await Promise.all([...refresh, 'overview', 'changes', 'edits'].map((key) => client.invalidateQueries({ queryKey: [key] })))
    },
    onError: (e) => toast((e as Error).message),
  })
  return (
    <span className="ml-1.5 inline-flex items-center gap-1 align-middle">
      <span className="rounded-full bg-blue/15 px-1.5 text-[10px] font-bold text-blue uppercase">new</span>
      <button type="button" aria-label="Remove" disabled={run.isPending}
        onClick={(e) => { e.stopPropagation(); if (confirm('Remove this item added in the Studio?')) run.mutate() }}
        className="rounded p-0.5 text-muted hover:bg-bad-soft hover:text-bad-ink">
        <Trash2 className="size-3.5" />
      </button>
    </span>
  )
}

