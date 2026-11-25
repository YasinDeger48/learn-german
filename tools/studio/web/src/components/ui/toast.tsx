import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react'

const ToastContext = createContext<(message: string) => void>(() => {})

/** Short messages at the bottom of the screen ("Saved", "Copied", errors). */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [message, setMessage] = useState('')
  const timer = useRef<number | undefined>(undefined)
  const show = useCallback((text: string) => {
    setMessage(text)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setMessage(''), 3200)
  }, [])
  return (
    <ToastContext.Provider value={show}>
      {children}
      <div
        role="status"
        aria-live="polite"
        className={`pointer-events-none fixed bottom-5 left-1/2 z-50 max-w-[80vw] -translate-x-1/2 rounded-lg bg-ink px-4 py-2 text-sm text-ground shadow-lg transition-opacity ${message ? 'opacity-100' : 'opacity-0'}`}
      >
        {message}
      </div>
    </ToastContext.Provider>
  )
}

export const useToast = () => useContext(ToastContext)
