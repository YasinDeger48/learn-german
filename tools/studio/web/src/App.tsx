import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from '@/components/layout/AppShell'
import { Grammar } from '@/pages/Grammar'
import { Inbox } from '@/pages/Inbox'
import { Media } from '@/pages/Media'
import { Overview } from '@/pages/Overview'
import { Publish } from '@/pages/Publish'
import { Tasks } from '@/pages/Tasks'
import { Texts } from '@/pages/Texts'
import { Translations } from '@/pages/Translations'
import { Units } from '@/pages/Units'
import { Verbs } from '@/pages/Verbs'
import { Words } from '@/pages/Words'

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
        <Route path="units" element={<Units />} />
        <Route path="units/:id" element={<Units />} />
        <Route path="media" element={<Media />} />
        <Route path="words" element={<Words />} />
        <Route path="words/:level" element={<Words />} />
        <Route path="grammar" element={<Grammar />} />
        <Route path="grammar/:level" element={<Grammar />} />
        <Route path="grammar/:level/:topic" element={<Grammar />} />
        <Route path="verbs" element={<Verbs />} />
        <Route path="verbs/:level" element={<Verbs />} />
        <Route path="verbs/:level/:verb" element={<Verbs />} />
        <Route path="tasks" element={<Tasks />} />
        <Route path="translations" element={<Translations />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
