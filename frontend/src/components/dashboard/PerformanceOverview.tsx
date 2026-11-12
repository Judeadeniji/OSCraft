import { DotsThree } from '@phosphor-icons/react'
import { RamUsageChart } from '@/components/dashboard/RamUsageChart'
import { CpuUsageChart } from '@/components/dashboard/CpuUsageChart'
import { SafetyVerification } from '@/components/dashboard/SafetyVerification'

export function PerformanceOverview() {
  return (
    <div className="rounded-3xl border border-slate-200/70 bg-white shadow-2xs p-6 space-y-6">
      {/* Header with Three-Dot Menu */}
      <div className="flex items-center justify-between">
        <h3 className="font-bold text-sm text-slate-900 tracking-tight">Performance Overview</h3>
        <button
          className="text-slate-400 hover:text-slate-700 p-1 rounded-md hover:bg-slate-100 transition-colors duration-150 cursor-pointer active:scale-90"
          title="Overview options"
        >
          <DotsThree className="size-5" weight="bold" />
        </button>
      </div>

      <RamUsageChart />
      <CpuUsageChart />
      <SafetyVerification />
    </div>
  )
}
