/** Typed calls to the Studio backend (tools/studio/app.py). Shapes mirror the Python responses. */

export type LevelRow = {
  level: string
  texts: number
  covers: number
  reviewed: number
  words: number
  grammarTopics: number
  grammarItems: number
  units: number
  verbsReady: number
  verbsTotal: number
  writing: number
  speaking: number
}

export type JobRow = {
  id: string
  group: string
  title: string
  requests: number
  answers: number
  progress: [number, number] | null
}

export type Overview = {
  levels: LevelRow[]
  units: { total: number; pictures: number; cards: number; cardsTotal: number }
  verbs: { ready: number; total: number }
  audio: { female: number; male: number; words: number; ambience: number }
  jobs: JobRow[]
  waiting: number
  languages: { code: string; name: string; percent: number; left?: number }[]
  commits: { id: string; date: string; message: string }[]
  unsaved: number
  today: string
}

export type InboxJob = {
  id: string
  group: string
  title: string
  requests: number[]
  answers: number[]
  progress: [number, number] | null
  guide: string
}

export type UnitStatus = {
  id: string
  level: string
  number: number
  title: string
  titleTr: string
  cover: string
  hasCover: boolean
  grid: string | null
  gridDone: number
  gridTotal: number
}

export type CheckResult = { lines: number; ok: number; problems: string[] }

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, init)
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body.detail || body.error || response.statusText)
  return body as T
}

const q = (job: string, n?: number) => `job=${encodeURIComponent(job)}${n === undefined ? '' : `&n=${n}`}`

export const api = {
  overview: () => call<Overview>('/api/overview'),
  inbox: () => call<{ jobs: InboxJob[]; units: UnitStatus[]; changes: string[] }>('/api/inbox'),
  request: (job: string, n: number) => call<{ text: string }>(`/api/inbox/request?${q(job, n)}`),
  check: (job: string, n: number) => call<CheckResult>(`/api/inbox/check?${q(job, n)}`),
  saveAnswer: (job: string, n: number, text: string) =>
    call<CheckResult>(`/api/inbox/answer?${q(job, n)}`, { method: 'POST', body: text }),
  importJob: (job: string) => call<{ output: string }>(`/api/inbox/import?${q(job)}`, { method: 'POST' }),
  openFolder: (job: string) => call<{ ok: boolean }>(`/api/inbox/open?${q(job)}`, { method: 'POST' }),
  picture: (file: File) =>
    call<{ message: string; pictures: string[] }>(`/api/picture?name=${encodeURIComponent(file.name)}`, {
      method: 'POST',
      body: file,
    }),
  publish: () => call<{ output: string }>('/api/publish', { method: 'POST' }),
  save: () => call<{ ok: boolean; message: string }>('/api/save-content', { method: 'POST' }),
  changes: () => call<{ content: string[]; texts: string[] }>('/api/changes'),
}
