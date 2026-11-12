import { CheckCircle } from '@phosphor-icons/react'

export function SafetyVerification() {
  return (
    <div className="pt-2 border-t border-slate-200/60 space-y-2.5">
      <div className="text-xs font-bold text-slate-800">Safety Verification</div>
      <div className="space-y-2 text-xs">
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
          <span className="text-slate-600 font-medium">Dry-Run Simulation</span>
          <span className="inline-flex items-center gap-1.5 font-bold text-emerald-600 text-xs">
            <CheckCircle className="size-4" weight="fill" />
            Active
          </span>
        </div>
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
          <span className="text-slate-600 font-medium">Alignment Guard</span>
          <span className="font-bold text-blue-600 text-xs font-mono">1 MiB Verified</span>
        </div>
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
          <span className="text-slate-600 font-medium">Firmware Interface</span>
          <span className="text-slate-700 text-xs font-mono">
            <code>UEFI 2.10 (x86_64)</code>
          </span>
        </div>
      </div>
    </div>
  )
}
