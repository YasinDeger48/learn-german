import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '@/components/layout/AppShell'
import { Inbox } from '@/pages/Inbox'
import { Overview } from '@/pages/Overview'
import { Publish } from '@/pages/Publish'
import { Soon } from '@/pages/Soon'

export default function App() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Overview />} />
        <Route path="inbox" element={<Inbox />} />
        <Route path="inbox/:job" element={<Inbox />} />
        <Route path="publish" element={<Publish />} />
        <Route path="texts" element={<Soon title="Daily texts" what="Review texts, covers, translations and questions. Until it moves here, use the classic page." classic={{ href: '/classic', label: 'Open classic texts page' }} />} />
        <Route path="units" element={<Soon title="Path units" what="All 43 units with their steps, phrases, words and pictures." classic={{ href: '/classic/inbox#units', label: 'Unit pictures (classic)' }} />} />
        <Route path="media" element={<Soon title="Media" what="Text covers, unit pictures, word cards and audio in one gallery, with drag and drop." classic={{ href: '/classic/inbox#units', label: 'Drop pictures (classic)' }} />} />
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
