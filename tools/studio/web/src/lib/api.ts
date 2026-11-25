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

export type ReviewState = { status?: 'ok' | 'fix'; note?: string; at?: string }

export type TextRow = { id: string; title: string; topic: string; cover: boolean; review: ReviewState; issues: string[] }

/** Texts in the learner languages: tr and en always, es / fr / it / ku / ar when translated. */
export type Langs = { tr: string; en?: string; [lang: string]: string | undefined }

export type Glossary = { form: string; lemma: string; art?: string; mean: Langs; pron?: string }

export type Question = { type: 'mc' | 'tf'; q: string; options: string[]; answer: number }

export type TextDetail = {
  level: string
  cover: boolean
  review: ReviewState
  issues: string[]
  prompt: string
  text: {
    id: string
    title: string
    topic?: string
    paragraphs: string[]
    trans?: Partial<Langs>[]
    glossary: Glossary[]
    questions: Question[]
  }
}

export type LevelSummary = { level: string; texts: number; covers: number; ok: number; fix: number }

export type CoverRow = { id: string; level: string; title: string; topic: string; cover: boolean; review?: 'ok' | 'fix' }

export type WordCardUnit = {
  unit: string
  title: string
  grid: string
  cards: { id: number; de: string; article: string | null; meaning: string; file: string; exists: boolean }[]
}

export type AudioInfo = {
  counts: Overview['audio']
  texts: { id: string; title: string; voices: ('f' | 'm')[] }[]
  ambience: { kind: string; name: string; by: string; license: string; source: string }[]
}

export type Loc = { tr: string; en: string }

export type UnitFull = {
  id: string
  level: string
  number: number
  title: Loc
  goal: Loc
  cover: string
  hasCover: boolean
  themes: string[]
  grammar: { id: number; de: string; name: string }[]
  texts: { id: string; title: string; cover: boolean }[]
  speaking: { id: string; title: string }[]
  writing: { id: string; title: string }[]
  phrases: { de: string; tr: string; en: string; added?: boolean; [lang: string]: string | boolean | undefined }[]
  words: { de: string; article: string | null; meaning: string; picture: string | null }[]
}

export type Sentence = { de: string; tr: string; en: string; t?: string; note?: string }

export type VerbEntry = {
  v: string
  tr: string
  en: string
  praesens: string[]
  praeteritum: string[]
  perfekt: string
  futur: string
  imperativ: string[]
  trennbar: boolean
  reflexiv: boolean
  rektion?: string
  examples: Sentence[]
  questions: Sentence[]
  common: Sentence[]
  complex: Sentence[]
}

export type VerbList = { level: string; ready: number; verbs: { v: string; meaning: string; entry: VerbEntry | null }[] }

export type WordRow = {
  id: number
  de: string
  type: string
  theme: string
  plural?: string
  pron: string
  tr: string
  en: string
  mean: Langs
  examples: { de: string; tr: string; en: string; mean: Langs }[]
  broken: boolean
  added?: boolean
}

export type GrammarTopic = {
  id: number
  de: string
  name: Loc
  rule: Loc
  examples: { de: string; tr: string; en: string }[]
  items: { q: string; answer: string; options: string[]; why: Partial<Loc>; broken: boolean; added?: boolean }[]
}

export type TaskPoint = { label: Loc; say: string; keys: string[] }

export type WritingTask = {
  id: string
  level: string
  kind: 'form' | 'message'
  title: Loc
  text?: string
  fields?: { label: string; answers: string[] }[]
  prompt?: string
  help?: Loc
  points?: TaskPoint[]
  minWords?: number
  sample?: string
  formal?: boolean
}

export type SpeakingTask = { id: string; level: string; seconds: number; title: Loc; prompt: string; help: Loc; points: TaskPoint[]; sample: string }

export type PatternBlock = { title: Loc; phrases: string[] }

export type TranslationStats = {
  languages: { code: string; name: string; ui: { total: number; done: number }; sets: { set: string; total: number; done: number }[] }[]
  sample?: { en: string; tr: string; text: string; where: 'app' | 'content' }[]
}

/** Where an editable text lives: an item of a list in a content file, and a dotted path inside it. */
export type EditTarget = { file: string; collection: string; keyField: string; key: string | number; path: string }

export type EditRecord = EditTarget & { op?: 'set' | 'add'; value: string; original: string; at: string; item?: Record<string, unknown> }

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

  // Daily texts (classic review endpoints)
  textSummary: () => call<{ levels: LevelSummary[]; changes: number }>('/api/summary'),
  texts: (level: string) => call<TextRow[]>(`/api/texts/${level}`),
  text: (id: string) => call<TextDetail>(`/api/text/${id}`),
  review: (id: string, status: '' | 'ok' | 'fix', note: string) =>
    call<{ ok: boolean }>(`/api/review/${id}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status, note }) }),
  putCover: (id: string, file: Blob, cropTop: number) => call<{ ok: boolean }>(`/api/cover/${id}?crop_top=${cropTop}`, { method: 'POST', body: file }),
  removeCover: (id: string) => call<{ ok: boolean }>(`/api/cover/${id}`, { method: 'DELETE' }),
  coverPrompts: (level: string) => call<{ count: number; text: string }>(`/api/prompts/${level}`),
  saveTexts: () => call<{ ok: boolean; message: string }>('/api/commit', { method: 'POST' }),

  // Path units and verb lab
  units: () => call<UnitFull[]>('/api/units'),
  verbs: (level: string) => call<VerbList>(`/api/verbs/${level}`),

  // Lists
  words: (level: string) => call<{ level: string; themes: string[]; themeList: { id: number; name: string }[]; words: WordRow[] }>(`/api/words/${level}`),
  grammar: (level: string) => call<{ level: string; topics: GrammarTopic[]; broken: number }>(`/api/grammar/${level}`),
  tasks: () => call<{ writing: WritingTask[]; speaking: SpeakingTask[]; pattern?: { informal: PatternBlock[]; formal: PatternBlock[] } }>('/api/tasks'),
  translations: (sample = '') => call<TranslationStats>(`/api/translations?sample=${sample}`),

  // Editing
  edit: (body: EditTarget & { value: string }) =>
    call<{ ok: boolean; old: string }>('/api/edit', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }),
  edits: () => call<EditRecord[]>('/api/edits'),
  add: (body: Record<string, unknown>) =>
    call<{ ok: boolean }>('/api/add', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }),
  remove: (body: { file: string; collection: string; item: Record<string, unknown>; parent?: { keyField: string; key: string; path: string } }) =>
    call<{ ok: boolean }>('/api/remove', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }),

  // Media
  covers: () => call<CoverRow[]>('/api/media/covers'),
  wordcards: () => call<WordCardUnit[]>('/api/media/wordcards'),
  audio: () => call<AudioInfo>('/api/media/audio'),
}
