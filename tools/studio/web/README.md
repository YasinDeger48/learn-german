# Deschly Studio · web

React + TypeScript + Vite + Tailwind admin panel for the Deschly content. The backend is `../app.py` (FastAPI).

- Run the Studio: `Deschly-Studio.cmd` (serves the built `dist/` on http://127.0.0.1:8765).
- Develop the UI: start the Studio, then `npm install` once and `npm run dev` here (http://localhost:5173, API proxied).
- Before committing UI changes: `npm run build` (dist/ is committed, so the Studio runs without Node).

Structure: `src/lib/api.ts` (typed API calls), `src/components/ui` (button, card, badge, progress, toast),
`src/components/layout` (sidebar shell, page header), `src/pages` (one file per page).
