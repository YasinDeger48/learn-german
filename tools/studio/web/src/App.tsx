import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '@/components/layout/AppShell'
import { Inbox } from '@/pages/Inbox'
import { Media } from '@/pages/Media'
import { Overview } from '@/pages/Overview'
import { Publish } from '@/pages/Publish'
import { Soon } from '@/pages/Soon'
import { Texts } from '@/pages/Texts'

export default function App() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Overview />} />
        <Route path="inbox" element={<Inbox />} />
        <Route path="inbox/:job" element={<Inbox />} />
        <Route path="publish" element={<Publish />} />
        <Route path="texts" element={<Texts />} />
        <Route path="texts/:id" element={<Texts />} />
        <Route path="units" element={<Soon title="Path units" what="All 43 units with their steps, phrases, words and pictures." classic={{ href: '/media?tab=units', label: 'Unit pictures in Media' }} />} />
        <Route path="media" element={<Media />} />
        <Route path="words" element={<Soon title="Words" what="Search and edit the word lists of every level." />} />
        <Route path="grammar" element={<Soon title="Grammar" what="Grammar topics and exercises per level." />} />
        <Route path="verbs" element={<Soon title="Verb lab" what="Every verb with its forms and sentences. Import answers in the ChatGPT inbox meanwhile." />} />
        <Route path="tasks" element={<Soon title="Writing & speaking" what="Writing and speaking tasks with their samples and checks." />} />
        <Route path="translations" element={<Soon title="Translations" what="Progress per language and level, with spot checks side by side." />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
