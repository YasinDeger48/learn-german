import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Rocket, Save } from 'lucide-react'
import { useState } from 'react'
import { Failed, Loading, PageHeader } from '@/components/layout/PageHeader'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader } from '@/components/ui/card'
import { useToast } from '@/components/ui/toast'
import { api } from '@/lib/api'

export function Publish() {
  const toast = useToast()
  const client = useQueryClient()
  const [output, setOutput] = useState('')
  const { data, error, isLoading } = useQuery({ queryKey: ['changes'], queryFn: api.changes })
  const edits = useQuery({ queryKey: ['edits'], queryFn: api.edits })
  const refresh = () => Promise.all(['changes', 'overview', 'inbox', 'edits'].map((key) => client.invalidateQueries({ queryKey: [key] })))

  const publish = useMutation({
    mutationFn: api.publish,
    onSuccess: (r) => { setOutput(r.output); toast('Published to the website folder') },
    onError: (e) => toast((e as Error).message),
  })
  const save = useMutation({
    mutationFn: api.save,
    onSuccess: async (r) => { toast(r.message); await refresh() },
    onError: (e) => toast((e as Error).message),
  })

  if (isLoading) return <Loading />
  if (error || !data) return <Failed error={error} />
  const files = data.content

  return (
    <div className="max-w-[920px]">
      <PageHeader title="Publish" description="Send new content to installed apps and keep it in git." />
      <div className="flex flex-col gap-[18px]">
        <Card>
          <CardBody>
            <ol className="m-0 flex flex-col gap-2 pl-5">
              <li><b>Publish to the website folder</b>: content, translations and pictures go to <code>deschly-site</code>; apps download them.</li>
              <li><b>Save</b>: commits the changed content in git (content, translations, unit and word pictures only).</li>
              <li>Upload with <b>Gizlilik-Sitesi-Yukle.cmd</b> (website) and <b>GitHub-iOS-Yukle.cmd</b> (app build).</li>
            </ol>
            <div className="mt-4 flex flex-wrap gap-2">
              <Button variant="primary" disabled={publish.isPending} onClick={() => publish.mutate()}><Rocket />{publish.isPending ? 'Publishing…' : '1 · Publish to the website folder'}</Button>
              <Button variant="gold" disabled={!files.length || save.isPending} onClick={() => save.mutate()}><Save />2 · Save {files.length} file{files.length === 1 ? '' : 's'}</Button>
            </div>
          </CardBody>
        </Card>
        {output && <pre className="m-0 max-h-[300px] overflow-auto rounded-xl border border-line bg-surface p-3 text-xs whitespace-pre-wrap">{output}</pre>}
        <Card className="overflow-hidden">
          <CardHeader title={files.length ? `Unsaved files (${files.length})` : 'Nothing to save'} />
          {files.length > 0 && (
            <ul className="m-0 max-h-[420px] list-none overflow-auto p-0">
              {files.map((f) => <li key={f} className="border-t border-line-soft px-[18px] py-2 font-mono text-xs first:border-t-0">{f}</li>)}
            </ul>
          )}
        </Card>
        <Card className="overflow-hidden">
          <CardHeader title={`Hand edits (${edits.data?.length ?? 0})`} action={<span className="text-xs text-muted">kept in tools/content_edits.json, re-applied before every publish</span>} />
          {edits.data && edits.data.length > 0 ? (
            <div className="max-h-[420px] overflow-auto">
              {edits.data.slice(0, 100).map((e, i) => (
                <div key={i} className="grid gap-0.5 border-t border-line-soft px-[18px] py-2 text-[13px] first:border-t-0">
                  <div className="text-xs text-muted">{e.at.replace('T', ' ')} · {e.file} · {e.collection} {String(e.key)} · {e.path}</div>
                  <div><span className="text-bad-ink line-through decoration-1">{e.original}</span> → <b>{e.value}</b></div>
                </div>
              ))}
            </div>
          ) : (
            <div className="px-[18px] py-4 text-muted">No hand edits yet. Hover a text in Words, Grammar, Path units or Daily texts and click the pencil.</div>
          )}
        </Card>
        {data.texts.length > 0 && (
          <div className="text-xs text-muted">
            {data.texts.length} text cover / review file{data.texts.length > 1 ? 's' : ''} changed outside the Studio (other tools); they are saved from the classic texts page.
          </div>
        )}
      </div>
    </div>
  )
}
