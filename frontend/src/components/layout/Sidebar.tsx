import { Link, useLocation } from '@tanstack/react-router'
import {
  Stack,
  HardDrives,
  Disc,
  GlobeHemisphereWest,
  Database,
  Cpu,
  Cube,
  Archive,
  Sparkle,
  ArrowsClockwise,
  TerminalWindow,
  Gear,
} from '@phosphor-icons/react'

export function Sidebar() {
  const location = useLocation()

  const navOverview = [
    { label: 'Disks & Topology', to: '/', icon: Stack, activeMatch: (p: string) => p === '/' },
    { label: 'Stacklets', to: '/', icon: HardDrives, activeMatch: () => false },
    { label: 'Images & Live ISO', to: '/', icon: Disc, activeMatch: () => false },
    { label: 'Networking', to: '/', icon: GlobeHemisphereWest, activeMatch: () => false },
    { label: 'Databases & Btrfs', to: '/', icon: Database, activeMatch: () => false },
    { label: 'Kubernetes', to: '/', icon: Cpu, activeMatch: () => false },
    { label: 'Volume', to: '/', icon: Cube, activeMatch: () => false },
    { label: 'Buckets', to: '/', icon: Archive, activeMatch: () => false },
    { label: 'OSCraft AI', to: '/', icon: Sparkle, activeMatch: () => false },
  ]

  const navOrganize = [
    { label: 'Zero-Reboot (kexec)', to: '/kexec', icon: ArrowsClockwise, activeMatch: (p: string) => p.startsWith('/kexec') },
    { label: 'Kernel API & IPC', to: '/settings', icon: TerminalWindow, activeMatch: () => false },
    { label: 'Settings', to: '/settings', icon: Gear, activeMatch: (p: string) => p.startsWith('/settings') },
  ]

  return (
    <aside className="w-64 h-full shrink-0 bg-slate-50/70 border-r border-slate-200/70 flex flex-col justify-between p-4.5 select-none z-20">
      <div className="space-y-6">
        {/* Window Traffic Lights & Logo */}
        <div className="space-y-4">
          {/* macOS Desktop Window Controls */}
          <div className="flex items-center gap-1.5 px-1 pt-0.5">
            <span className="size-3 rounded-full bg-[#ff5f56] border border-[#e0443e]/40 shadow-2xs" />
            <span className="size-3 rounded-full bg-[#ffbd2e] border border-[#dea123]/40 shadow-2xs" />
            <span className="size-3 rounded-full bg-[#27c93f] border border-[#1aab29]/40 shadow-2xs" />
          </div>

          {/* Brand Identity */}
          <Link to="/" className="flex items-center gap-3 group px-1">
            <div className="size-9 rounded-xl bg-blue-600 flex items-center justify-center text-white shadow-sm shadow-blue-500/25 group-hover:scale-105 active:scale-95 transition-transform duration-200">
              <svg className="size-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 2L2 7L12 12L22 7L12 2Z" fill="currentColor" opacity="0.95" />
                <path d="M2 17L12 22L22 17" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M2 12L12 17L22 12" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" opacity="0.8" />
              </svg>
            </div>
            <div className="flex flex-col">
              <span className="font-bold text-slate-900 text-base tracking-tight leading-none">OSCraft</span>
              <span className="text-[10px] text-slate-500 font-medium tracking-wide mt-1">Kernel & Storage Manager</span>
            </div>
          </Link>
        </div>

        {/* Navigation: OVERVIEW */}
        <div>
          <div className="text-[10px] font-bold tracking-wider uppercase text-slate-400 px-3 mb-2">
            Overview
          </div>
          <nav className="space-y-0.5">
            {navOverview.map((item) => {
              const Icon = item.icon
              const isActive = item.activeMatch(location.pathname)
              return (
                <Link
                  key={item.label}
                  to={item.to}
                  className={`flex items-center gap-3 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 active:scale-[0.98] ${
                    isActive
                      ? 'text-blue-600 bg-blue-50/90 shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50'
                  }`}
                >
                  <Icon className={`size-4.5 ${isActive ? 'text-blue-600' : 'text-slate-400'}`} weight={isActive ? 'bold' : 'regular'} />
                  <span>{item.label}</span>
                </Link>
              )
            })}
          </nav>
        </div>

        {/* Navigation: ORGANIZE */}
        <div>
          <div className="text-[10px] font-bold tracking-wider uppercase text-slate-400 px-3 mb-2">
            Organize
          </div>
          <nav className="space-y-0.5">
            {navOrganize.map((item) => {
              const Icon = item.icon
              const isActive = item.activeMatch(location.pathname)
              return (
                <Link
                  key={item.label}
                  to={item.to}
                  className={`flex items-center gap-3 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 active:scale-[0.98] ${
                    isActive
                      ? 'text-blue-600 bg-blue-50/90 shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50'
                  }`}
                >
                  <Icon className={`size-4.5 ${isActive ? 'text-blue-600' : 'text-slate-400'}`} weight={isActive ? 'bold' : 'regular'} />
                  <span>{item.label}</span>
                </Link>
              )
            })}
          </nav>
        </div>
      </div>

      {/* Sidebar Footer Status Pill */}
      <div className="pt-3 border-t border-slate-200/60 flex items-center justify-between text-xs text-slate-500 px-1">
        <div className="flex items-center gap-2">
          <span className="size-2 rounded-full bg-emerald-500 ring-2 ring-emerald-500/20" />
          <span className="font-semibold text-slate-700 text-[11px]">Kernel Direct</span>
        </div>
        <code className="text-[11px] text-slate-500 font-mono bg-slate-200/60 px-1.5 py-0.5 rounded">v0.4.2</code>
      </div>
    </aside>
  )
}
