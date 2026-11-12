import { Stack, Plus } from '@phosphor-icons/react'
import { TabType } from '@/types/storage'

interface ProjectHeaderProps {
  activeTab: TabType
  onSelectTab: (tab: TabType) => void
  onRefresh: () => void
  isRefreshing: boolean
}

export function ProjectHeader({
  activeTab,
  onSelectTab,
  onRefresh,
  isRefreshing,
}: ProjectHeaderProps) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-1">
      <div className="flex items-center gap-4">
        {/* Double-Bezel Project Icon Box */}
        <div className="p-1 rounded-2xl bg-blue-50/70 border border-blue-100/60 shadow-2xs">
          <div className="size-12 rounded-xl bg-blue-600 text-white flex items-center justify-center shadow-xs">
            <Stack className="size-6" weight="bold" />
          </div>
        </div>
        <div>
          <h1 className="text-xl font-bold tracking-tight text-slate-900 leading-tight">
            My Project
          </h1>
          <p className="text-xs font-semibold text-slate-500 mt-0.5">
            Storage & Topology Overview
          </p>
        </div>
      </div>

      {/* Segmented Filter Pills + Circular CTA */}
      <div className="flex items-center gap-3">
        <div className="bg-slate-100/90 p-1 rounded-full flex items-center gap-1 border border-slate-200/60 shadow-2xs">
          <button
            onClick={() => onSelectTab('resources')}
            className={`px-4.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer active:scale-95 ${
              activeTab === 'resources'
                ? 'bg-slate-900 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Resources
          </button>
          <button
            onClick={() => onSelectTab('member')}
            className={`px-4.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer active:scale-95 ${
              activeTab === 'member'
                ? 'bg-slate-900 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Member
          </button>
          <button
            onClick={() => onSelectTab('setting')}
            className={`px-4.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer active:scale-95 ${
              activeTab === 'setting'
                ? 'bg-slate-900 text-white shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Setting
          </button>
        </div>

        {/* Circular Blue Action Button */}
        <button
          onClick={onRefresh}
          title="Rescan Storage Devices"
          disabled={isRefreshing}
          className="size-9 rounded-full bg-blue-600 hover:bg-blue-700 active:scale-90 text-white flex items-center justify-center shadow-md shadow-blue-500/25 transition-all duration-200 cursor-pointer disabled:opacity-50"
        >
          <Plus className={`size-5 ${isRefreshing ? 'animate-spin' : ''}`} weight="bold" />
        </button>
      </div>
    </div>
  )
}
