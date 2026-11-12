import { createFileRoute, useRouter } from '@tanstack/react-router'
import { useState } from 'react'
import {
  Layers,
  Plus,
  ChevronDown,
  ChevronUp,
  MoreHorizontal,
  CheckCircle2,
  ArrowUpRight,
} from 'lucide-react'

interface Partition {
  name: string
  label: string
  fsType: string
  sizeBytes: number
  mountPoint?: string
  isBoot: boolean
}

interface Disk {
  path: string
  model: string
  sizeBytes: number
  tableType: 'GPT' | 'MBR' | 'RAW'
  ipAddress?: string
  enabled?: boolean
  partitions: Partition[]
}

const DEFAULT_DISKS: Disk[] = [
  {
    path: '/dev/nvme0n1',
    model: 'Samsung SSD 990 PRO 2TB',
    sizeBytes: 2000398934016,
    tableType: 'GPT',
    ipAddress: '50.3.80.29',
    enabled: true,
    partitions: [
      { name: '/dev/nvme0n1p1', label: 'EFI System', fsType: 'vfat', sizeBytes: 1073741824, mountPoint: '/boot/efi', isBoot: true },
      { name: '/dev/nvme0n1p2', label: 'OSCraft-Root', fsType: 'btrfs', sizeBytes: 1999325192192, mountPoint: '/', isBoot: false },
    ],
  },
  {
    path: '/dev/sda',
    model: 'SanDisk Ultra USB 3.0',
    sizeBytes: 32000000000,
    tableType: 'GPT',
    ipAddress: '50.3.80.26',
    enabled: false,
    partitions: [
      { name: '/dev/sda1', label: 'LIVE-BOOT', fsType: 'ext4', sizeBytes: 31998951424, mountPoint: '/run/live', isBoot: true },
    ],
  },
]

async function probeDisksLoader(): Promise<Disk[]> {
  if (typeof window !== 'undefined' && window.nanoui) {
    try {
      const probed = await window.nanoui.call<Disk[]>('storage.probeDisks')
      if (probed && probed.length > 0) {
        return probed.map((d, i) => ({
          ...d,
          ipAddress: d.ipAddress || (i === 0 ? '50.3.80.29' : '50.3.80.26'),
          enabled: i === 0,
        }))
      }
    } catch (err) {
      console.warn('IPC probe failed:', err)
    }
  }
  return DEFAULT_DISKS
}

export const Route = createFileRoute('/')({
  loader: async () => probeDisksLoader(),
  component: DiskManagerComponent,
})

const formatBytes = (bytes: number) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`
}

function DebianSpiral({ className = 'size-5' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12.18 3.5c-4.69.09-8.48 3.96-8.38 8.66.08 4.34 3.45 7.92 7.77 8.25.82.06 1.3-.58 1.21-1.22-.07-.53-.4-1-.61-1.49-.31-.72-.45-1.52-.39-2.3.14-2.01 1.79-3.59 3.8-3.56.85.01 1.66.34 2.31.89.5.42 1.18.48 1.74.17.84-.46 1.04-1.53.45-2.26-1.57-1.94-4.55-4.73-7.9-4.64z" />
      <circle cx="9" cy="11.5" r="1.3" fill="white" />
    </svg>
  )
}

export function DiskManagerComponent() {
  const router = useRouter()
  const initialDisks = Route.useLoaderData()
  const [activeTab, setActiveTab] = useState<'resources' | 'member' | 'setting'>('resources')
  const [disks, setDisks] = useState<Disk[]>(initialDisks)
  const [expandedDisk, setExpandedDisk] = useState<string | null>('/dev/nvme0n1')
  const [isRefreshing, setIsRefreshing] = useState(false)

  const handleRefresh = async () => {
    setIsRefreshing(true)
    try {
      const fresh = await probeDisksLoader()
      setDisks(fresh)
      router.invalidate()
    } finally {
      setIsRefreshing(false)
    }
  }

  const toggleDisk = (path: string) => {
    setDisks((prev) =>
      prev.map((d) => (d.path === path ? { ...d, enabled: !d.enabled } : d))
    )
  }

  return (
    <div className="grid grid-cols-1 xl:grid-cols-12 gap-8 items-start max-w-7xl mx-auto">
      {/* Center Main Stage (7-8 cols on wide displays) */}
      <div className="xl:col-span-8 space-y-8">
        {/* Project Header Bar (Inspired by SimplyStack on Dribbble) */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-1">
          <div className="flex items-center gap-4">
            {/* Double-Bezel Project Icon Box */}
            <div className="p-1 rounded-2xl bg-blue-50/70 border border-blue-100/60 shadow-2xs">
              <div className="size-12 rounded-xl bg-blue-600 text-white flex items-center justify-center shadow-xs">
                <Layers className="size-6 stroke-[2.2]" />
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
                onClick={() => setActiveTab('resources')}
                className={`px-4.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer active:scale-95 ${
                  activeTab === 'resources'
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Resources
              </button>
              <button
                onClick={() => setActiveTab('member')}
                className={`px-4.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer active:scale-95 ${
                  activeTab === 'member'
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Member
              </button>
              <button
                onClick={() => setActiveTab('setting')}
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
              onClick={handleRefresh}
              title="Rescan Storage Devices"
              disabled={isRefreshing}
              className="size-9 rounded-full bg-blue-600 hover:bg-blue-700 active:scale-90 text-white flex items-center justify-center shadow-md shadow-blue-500/25 transition-all duration-200 cursor-pointer disabled:opacity-50"
            >
              <Plus className={`size-5 stroke-[2.5] ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {/* Section 1: Stacklets (Physical Storage Drives) */}
        <div className="space-y-3.5">
          <div className="flex items-center justify-between px-1">
            <h2 className="text-sm font-bold text-slate-800 tracking-tight">Stacklets</h2>
            <span className="text-xs font-semibold text-slate-500">
              {disks.length} Block Devices Active
            </span>
          </div>

          <div className="space-y-3">
            {disks.map((d) => {
              const isExpanded = expandedDisk === d.path
              return (
                <div
                  key={d.path}
                  className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 transition-all duration-200 overflow-hidden"
                >
                  {/* Card Row */}
                  <div className="p-4 sm:p-5 flex items-center justify-between gap-4">
                    {/* Left: Debian Icon + Name/Specs */}
                    <div className="flex items-center gap-3.5 min-w-0">
                      <div className="size-10 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 border border-blue-100/70 shadow-2xs">
                        <DebianSpiral className="size-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="font-bold text-sm text-slate-900 truncate">
                          {d.path === '/dev/nvme0n1' ? 'secret-opiniion-x4lihn' : 'backup-node-s02z1a'}
                        </div>
                        <div className="text-[11px] font-medium text-slate-500 truncate mt-0.5">
                          {d.path === '/dev/nvme0n1' ? '2GB / 50GB / FRA' : '1GB / 32GB / USB'}
                        </div>
                      </div>
                    </div>

                    {/* Middle: IP / Size address */}
                    <div className="font-bold text-xs sm:text-sm text-slate-800 tracking-tight shrink-0 font-mono">
                      <code>{d.ipAddress || '50.3.80.29'}</code>
                    </div>

                    {/* Right: iOS-Style Toggle Switch + Accordion Chevron */}
                    <div className="flex items-center gap-3 shrink-0">
                      {/* Live Toggle Switch */}
                      <button
                        type="button"
                        onClick={() => toggleDisk(d.path)}
                        className={`w-11 h-6 rounded-full transition-colors duration-200 relative cursor-pointer focus:outline-hidden ${
                          d.enabled ? 'bg-emerald-500' : 'bg-slate-200'
                        }`}
                        title={d.enabled ? 'Disable block device' : 'Enable block device'}
                      >
                        <span
                          className={`size-5 rounded-full bg-white shadow-2xs absolute top-0.5 left-0.5 transition-transform duration-200 ease-[cubic-bezier(0.16,1,0.3,1)] ${
                            d.enabled ? 'translate-x-5' : 'translate-x-0'
                          }`}
                        />
                      </button>

                      {/* Expand / Collapse Chevron */}
                      <button
                        onClick={() => setExpandedDisk(isExpanded ? null : d.path)}
                        className="size-7 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center transition-all duration-150 active:scale-90 cursor-pointer"
                        title="Toggle topology breakdown"
                      >
                        {isExpanded ? (
                          <ChevronUp className="size-4" />
                        ) : (
                          <ChevronDown className="size-4" />
                        )}
                      </button>
                    </div>
                  </div>

                  {/* Expanded Topology Breakdown (Visual Bar + Partition Table) */}
                  {isExpanded && (
                    <div className="px-5 pb-5 pt-2 border-t border-slate-100 bg-slate-50/50 space-y-4">
                      {/* Visual Sector Bar */}
                      <div>
                        <div className="flex items-center justify-between text-[11px] font-semibold text-slate-600 mb-2">
                          <span>SECTOR ALLOCATION : {d.model}</span>
                          <span><code>{formatBytes(d.sizeBytes)} ({d.tableType})</code></span>
                        </div>
                        <div className="h-7 w-full rounded-xl overflow-hidden bg-slate-200 flex p-1 gap-1 border border-slate-200/80">
                          {d.partitions.map((part) => {
                            const pct = Math.max(15, (part.sizeBytes / d.sizeBytes) * 100)
                            return (
                              <div
                                key={part.name}
                                style={{ width: `${pct}%` }}
                                className={`h-full rounded-lg flex items-center justify-center px-2 text-[10px] font-bold truncate shadow-2xs ${
                                  part.fsType === 'vfat'
                                    ? 'bg-amber-300 text-amber-950 border border-amber-400'
                                    : 'bg-blue-600 text-white'
                                }`}
                                title={`${part.name} (${part.fsType}): ${formatBytes(part.sizeBytes)}`}
                              >
                                <code>{part.name.split('/').pop()} ({part.fsType})</code>
                              </div>
                            )
                          })}
                        </div>
                      </div>

                      {/* Partitions Table */}
                      <div className="rounded-xl border border-slate-200/70 bg-white overflow-hidden text-xs shadow-2xs">
                        <table className="w-full text-left">
                          <thead className="bg-slate-50 text-slate-600 font-semibold text-[11px] border-b border-slate-200/70">
                            <tr>
                              <th className="py-2.5 px-3">Partition</th>
                              <th className="py-2.5 px-3">Label</th>
                              <th className="py-2.5 px-3">Filesystem</th>
                              <th className="py-2.5 px-3">Capacity</th>
                              <th className="py-2.5 px-3">Mount Point</th>
                            </tr>
                          </thead>
                          <tbody>
                            {d.partitions.map((p) => (
                              <tr key={p.name} className="border-b border-slate-100 hover:bg-slate-50/80 transition-colors duration-150">
                                <td className="py-2 px-3 font-semibold text-slate-800">
                                  <code>{p.name}</code>
                                </td>
                                <td className="py-2 px-3 text-slate-600">{p.label || '—'}</td>
                                <td className="py-2 px-3">
                                  <span className="uppercase text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-700">
                                    {p.fsType}
                                  </span>
                                </td>
                                <td className="py-2 px-3 text-slate-700"><code>{formatBytes(p.sizeBytes)}</code></td>
                                <td className="py-2 px-3 font-medium text-blue-600">
                                  <code>{p.mountPoint || 'Not mounted'}</code>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* Section 2: Kubernetes (Active Root & System Mounts) */}
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

            {/* Right: Toggle Switch + Chevron */}
            <div className="flex items-center gap-3 shrink-0">
              <button
                type="button"
                className="w-11 h-6 rounded-full bg-emerald-500 relative cursor-pointer focus:outline-hidden"
              >
                <span className="size-5 rounded-full bg-white shadow-2xs absolute top-0.5 left-0.5 translate-x-5 transition-transform duration-200 ease-[cubic-bezier(0.16,1,0.3,1)]" />
              </button>
              <button className="size-7 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center transition-all duration-150 active:scale-90">
                <ChevronDown className="size-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Section 3: Upcoming Services (Double-Bezel Grid Cards with BETA Badges & Island CTA) */}
        <div className="space-y-3.5">
          <div className="px-1">
            <h2 className="text-sm font-bold text-slate-800 tracking-tight">Upcoming Services</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Card 1: Volumes BETA */}
            <div className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 p-5 transition-all duration-200 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 mb-2.5">
                  <span className="font-bold text-sm text-slate-900">Volumes</span>
                  <span className="bg-orange-500 text-white font-bold text-[10px] px-2 py-0.5 rounded-full tracking-wider shadow-2xs">
                    BETA
                  </span>
                </div>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Add volume storage to increase your storage space in a seconds
                </p>
              </div>
              <button className="group mt-4 flex items-center justify-between w-full p-2 rounded-xl bg-slate-50 hover:bg-blue-50 text-slate-700 hover:text-blue-600 font-semibold text-xs transition-all duration-200 active:scale-[0.98] cursor-pointer">
                <span>Configure Volume</span>
                <span className="size-6 rounded-full bg-white shadow-2xs flex items-center justify-center text-slate-400 group-hover:text-blue-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all duration-200">
                  <ArrowUpRight className="size-3.5" />
                </span>
              </button>
            </div>

            {/* Card 2: Buckets BETA */}
            <div className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 p-5 transition-all duration-200 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 mb-2.5">
                  <span className="font-bold text-sm text-slate-900">Buckets</span>
                  <span className="bg-orange-500 text-white font-bold text-[10px] px-2 py-0.5 rounded-full tracking-wider shadow-2xs">
                    BETA
                  </span>
                </div>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Add buckets storage to increase your storage space in a seconds
                </p>
              </div>
              <button className="group mt-4 flex items-center justify-between w-full p-2 rounded-xl bg-slate-50 hover:bg-blue-50 text-slate-700 hover:text-blue-600 font-semibold text-xs transition-all duration-200 active:scale-[0.98] cursor-pointer">
                <span>Manage Buckets</span>
                <span className="size-6 rounded-full bg-white shadow-2xs flex items-center justify-center text-slate-400 group-hover:text-blue-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all duration-200">
                  <ArrowUpRight className="size-3.5" />
                </span>
              </button>
            </div>

            {/* Card 3: Simply AI BETA */}
            <div className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 p-5 transition-all duration-200 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 mb-2.5">
                  <span className="font-bold text-sm text-slate-900">Simply AI</span>
                  <span className="bg-orange-500 text-white font-bold text-[10px] px-2 py-0.5 rounded-full tracking-wider shadow-2xs">
                    BETA
                  </span>
                </div>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Glimps to add storage to increase your storage space in a seconds
                </p>
              </div>
              <button className="group mt-4 flex items-center justify-between w-full p-2 rounded-xl bg-slate-50 hover:bg-blue-50 text-slate-700 hover:text-blue-600 font-semibold text-xs transition-all duration-200 active:scale-[0.98] cursor-pointer">
                <span>Explore AI Tools</span>
                <span className="size-6 rounded-full bg-white shadow-2xs flex items-center justify-center text-slate-400 group-hover:text-blue-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all duration-200">
                  <ArrowUpRight className="size-3.5" />
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Right Column: Performance Overview (Awwwards-Tier Micro-Aesthetics) */}
      <div className="xl:col-span-4 rounded-3xl border border-slate-200/70 bg-white shadow-2xs p-6 space-y-6">
        {/* Header with Three-Dot Menu */}
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-sm text-slate-900 tracking-tight">Performance Overview</h3>
          <button className="text-slate-400 hover:text-slate-700 p-1 rounded-md hover:bg-slate-100 transition-colors duration-150 cursor-pointer active:scale-90">
            <MoreHorizontal className="size-4" />
          </button>
        </div>

        {/* Subsection 1: RAM Usage Bar Chart */}
        <div className="space-y-3">
          <div className="text-xs font-bold text-slate-800">RAM Usage</div>
          <div className="bg-slate-50/80 rounded-2xl p-5 border border-slate-200/60 shadow-2xs">
            {/* Chart Area with 7 Vertical Bars */}
            <div className="h-32 flex items-end justify-between gap-2.5 pt-6 relative">
              {/* Sun */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '42%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Sun</span>
              </div>

              {/* Mon */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '58%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Mon</span>
              </div>

              {/* Tue */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '72%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Tue</span>
              </div>

              {/* Wed */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '62%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Wed</span>
              </div>

              {/* Thu (Active Highlighted Dark Bar with Tooltip Pill) */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end relative">
                {/* Floating Black Tooltip Pill */}
                <div className="absolute -top-4 bg-slate-900 text-white font-bold text-[10px] px-2 py-0.5 rounded-md shadow-xs animate-bounce">
                  25%
                </div>
                <div className="w-full bg-slate-900 rounded-lg shadow-xs hover:bg-slate-800 transition-colors" style={{ height: '90%' }} />
                <span className="text-[11px] text-slate-900 font-bold">Thu</span>
              </div>

              {/* Fri */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '78%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Fri</span>
              </div>

              {/* Sat */}
              <div className="flex-1 flex flex-col items-center gap-2 h-full justify-end">
                <div className="w-full bg-blue-100 rounded-lg transition-all duration-300 hover:bg-blue-200" style={{ height: '36%' }} />
                <span className="text-[11px] text-slate-500 font-medium">Sat</span>
              </div>
            </div>
          </div>
        </div>

        {/* Subsection 2: CPU Usage Lollipop/Stick Chart */}
        <div className="space-y-3 pt-1">
          <div className="flex items-center justify-between">
            <div className="text-xs font-bold text-slate-800">CPU Usage</div>
          </div>

          {/* Legend */}
          <div className="flex items-center gap-3 text-[11px] font-medium text-slate-600">
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-full bg-slate-800" />
              All
            </span>
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-full bg-slate-400" />
              Applications
            </span>
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-full bg-blue-600" />
              Performance
            </span>
          </div>

          {/* Vertical Stick / Lollipop Chart across 6 months */}
          <div className="bg-slate-50/80 rounded-2xl p-5 border border-slate-200/60 shadow-2xs">
            <div className="h-28 flex items-end justify-between gap-3 pt-2">
              {[
                { month: 'Jan', height: '45%' },
                { month: 'Feb', height: '65%' },
                { month: 'Mar', height: '35%' },
                { month: 'Apr', height: '80%' },
                { month: 'May', height: '55%' },
                { month: 'Jun', height: '90%' },
              ].map((item) => (
                <div key={item.month} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group cursor-pointer">
                  <div className="relative flex flex-col items-center transition-transform duration-200 group-hover:scale-110" style={{ height: item.height }}>
                    {/* Blue Bead Top */}
                    <div className="size-2 rounded-full bg-blue-600 shadow-2xs group-hover:bg-blue-500" />
                    {/* Thin Line Stick */}
                    <div className="w-0.5 flex-1 bg-slate-300 group-hover:bg-blue-300 transition-colors" />
                  </div>
                  <span className="text-[11px] text-slate-500 font-medium group-hover:text-slate-800 transition-colors">{item.month}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Subsection 3: Kernel Guardrails & Safety */}
        <div className="pt-2 border-t border-slate-200/60 space-y-2.5">
          <div className="text-xs font-bold text-slate-800">Safety Verification</div>
          <div className="space-y-2 text-xs">
            <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
              <span className="text-slate-600 font-medium">Dry-Run Simulation</span>
              <span className="inline-flex items-center gap-1.5 font-bold text-emerald-600 text-xs">
                <CheckCircle2 className="size-3.5" />
                Active
              </span>
            </div>
            <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
              <span className="text-slate-600 font-medium">Alignment Guard</span>
              <span className="font-bold text-blue-600 text-xs font-mono">1 MiB Verified</span>
            </div>
            <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-50 border border-slate-200/50 shadow-2xs">
              <span className="text-slate-600 font-medium">Firmware Interface</span>
              <span className="text-slate-700 text-xs font-mono"><code>UEFI 2.10 (x86_64)</code></span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
