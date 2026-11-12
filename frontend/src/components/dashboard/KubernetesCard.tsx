import { CaretDown } from '@phosphor-icons/react'
import { DebianSpiral } from '@/components/icons/DebianSpiral'

export function KubernetesCard() {
  return (
    <div className="space-y-3.5">
      <div className="flex items-center justify-between px-1">
        <h2 className="text-sm font-bold text-slate-800 tracking-tight">Kubernetes</h2>
        <span className="text-xs font-semibold text-slate-500">1 Cluster Node Mounted</span>
      </div>

      <div className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 transition-all duration-200 p-4 sm:p-5 flex items-center justify-between gap-4">
        {/* Left: Distro icon + Specs */}
        <div className="flex items-center gap-3.5 min-w-0">
          <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 border border-blue-100/70 shadow-2xs">
            <DebianSpiral className="size-5" />
          </div>
          <div className="min-w-0">
            <div className="font-bold text-sm text-slate-900 truncate">
              secret-opiniion-x4lihn
            </div>
            <div className="text-[11px] font-medium text-slate-500 truncate mt-0.5">
              2GB / 50GB / FRA
            </div>
          </div>
        </div>

        {/* Middle: IP Address */}
        <div className="font-bold text-xs sm:text-sm text-slate-800 tracking-tight shrink-0 font-mono">
          <code>50.3.80.30</code>
        </div>

        {/* Right: Toggle Switch + Caret */}
        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            className="w-11 h-6 rounded-full bg-emerald-500 relative cursor-pointer focus:outline-hidden"
          >
            <span className="size-5 rounded-full bg-white shadow-2xs absolute top-0.5 left-0.5 translate-x-5 transition-transform duration-200 ease-[cubic-bezier(0.16,1,0.3,1)]" />
          </button>
          <button className="size-7 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center transition-all duration-150 active:scale-90">
            <CaretDown className="size-4" weight="bold" />
          </button>
        </div>
      </div>
    </div>
  )
}
