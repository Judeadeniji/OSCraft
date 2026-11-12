import { CaretDown, CaretUp } from '@phosphor-icons/react'
import { DebianSpiral } from '@/components/icons/DebianSpiral'
import { TopologyBar } from '@/components/dashboard/TopologyBar'
import { Disk } from '@/types/storage'

interface StackletCardProps {
  disk: Disk
  isExpanded: boolean
  onToggleExpand: () => void
  onToggleEnabled: () => void
}

export function StackletCard({
  disk,
  isExpanded,
  onToggleExpand,
  onToggleEnabled,
}: StackletCardProps) {
  const isPrimary = disk.path === '/dev/nvme0n1'

  return (
    <div className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 transition-all duration-200 overflow-hidden">
      {/* Card Header Row */}
      <div className="p-4 sm:p-5 flex items-center justify-between gap-4">
        {/* Left: Distro Icon + Identifier/Specs */}
        <div className="flex items-center gap-3.5 min-w-0">
          <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 border border-blue-100/70 shadow-2xs">
            <DebianSpiral className="size-5" />
          </div>
          <div className="min-w-0">
            <div className="font-bold text-sm text-slate-900 truncate">
              {isPrimary ? 'secret-opiniion-x4lihn' : 'backup-node-s02z1a'}
            </div>
            <div className="text-[11px] font-medium text-slate-500 truncate mt-0.5">
              {isPrimary ? '2GB / 50GB / FRA' : '1GB / 32GB / USB'}
            </div>
          </div>
        </div>

        {/* Middle: Address */}
        <div className="font-bold text-xs sm:text-sm text-slate-800 tracking-tight shrink-0 font-mono">
          <code>{disk.ipAddress || '50.3.80.29'}</code>
        </div>

        {/* Right: iOS-Style Toggle Switch + Accordion Caret */}
        <div className="flex items-center gap-3 shrink-0">
          {/* Live Toggle Switch */}
          <button
            type="button"
            onClick={onToggleEnabled}
            className={`w-11 h-6 rounded-full transition-colors duration-200 relative cursor-pointer focus:outline-hidden ${
              disk.enabled ? 'bg-emerald-500' : 'bg-slate-200'
            }`}
            title={disk.enabled ? 'Disable block device' : 'Enable block device'}
          >
            <span
              className={`size-5 rounded-full bg-white shadow-2xs absolute top-0.5 left-0.5 transition-transform duration-200 ease-[cubic-bezier(0.16,1,0.3,1)] ${
                disk.enabled ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>

          {/* Expand / Collapse Caret */}
          <button
            onClick={onToggleExpand}
            className="size-7 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center transition-all duration-150 active:scale-90 cursor-pointer"
            title="Toggle topology breakdown"
          >
            {isExpanded ? (
              <CaretUp className="size-4" weight="bold" />
            ) : (
              <CaretDown className="size-4" weight="bold" />
            )}
          </button>
        </div>
      </div>

      {/* Expanded Topology Breakdown */}
      {isExpanded && <TopologyBar disk={disk} />}
    </div>
  )
}
