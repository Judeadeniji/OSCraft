import { createFileRoute } from '@tanstack/react-router'
import { Settings, Server, Layers, Cpu, Code2, Globe } from 'lucide-react'

export const Route = createFileRoute('/settings')({
  component: SettingsComponent,
})

function SettingsComponent() {
  return (
    <div className="space-y-7 max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-4 pb-2">
        <div className="size-13 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center shadow-xs border border-blue-100/60">
          <Settings className="size-6 stroke-[2.2]" />
        </div>
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900 leading-tight">
            Settings & Runtime Parameters
          </h1>
          <p className="text-xs font-medium text-slate-400 mt-0.5">
            nanoui System Webview IPC bridge diagnostics and frontend stack configurations.
          </p>
        </div>
      </div>

      {/* Settings Grid */}
      <div className="grid gap-6">
        <div className="bg-white rounded-3xl border border-slate-100 shadow-xs p-6 space-y-5">
          <div className="flex items-center gap-3">
            <div className="size-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-100">
              <Server className="size-5" />
            </div>
            <div>
              <h2 className="font-bold text-sm text-slate-900">Frontend Environment</h2>
              <p className="text-[11px] text-slate-400">Active toolchain packages and bridges</p>
            </div>
          </div>

          <div className="space-y-2.5 text-xs">
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
              <span className="text-slate-600 font-medium">Package Manager</span>
              <span className="font-mono text-[11px] font-bold text-slate-800 bg-white px-3 py-1 rounded-full border border-slate-200">
                Bun 1.4.x
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
              <span className="text-slate-600 font-medium">UI Framework</span>
              <span className="font-mono text-[11px] font-bold text-slate-800 bg-white px-3 py-1 rounded-full border border-slate-200">
                React 19 + TypeScript
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
              <span className="text-slate-600 font-medium">Routing System</span>
              <span className="font-mono text-[11px] font-bold text-slate-800 bg-white px-3 py-1 rounded-full border border-slate-200">
                TanStack Router (File-Based)
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
              <span className="text-slate-600 font-medium">Styling Engine</span>
              <span className="font-mono text-[11px] font-bold text-slate-800 bg-white px-3 py-1 rounded-full border border-slate-200">
                Tailwind CSS v4 (@tailwindcss/vite)
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-100">
              <span className="text-slate-600 font-medium">Host Webview IPC</span>
              <span className="font-mono text-[11px] font-bold text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-100">
                nanoui IPC Bridge (Zig Native)
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
