import { createRootRoute, Link, Outlet, useLocation } from '@tanstack/react-router'
import {
  Layers,
  HardDrive,
  RefreshCw,
  Settings,
  Search,
  Bell,
  Globe,
  Database,
  Cpu,
  Box,
  FolderArchive,
  Sparkles,
  Code2,
  Terminal,
} from 'lucide-react'
import { useState } from 'react'

export const Route = createRootRoute({
  component: RootComponent,
})

function RootComponent() {
  const location = useLocation()
  const [searchQuery, setSearchQuery] = useState('')

  const navOverview = [
    { label: 'Disks & Topology', to: '/', icon: Layers, activeMatch: (p: string) => p === '/' },
    { label: 'Stacklets', to: '/', icon: HardDrive, activeMatch: () => false },
    { label: 'Images & Live ISO', to: '/', icon: Box, activeMatch: () => false },
    { label: 'Networking', to: '/', icon: Globe, activeMatch: () => false },
    { label: 'Databases & Btrfs', to: '/', icon: Database, activeMatch: () => false },
    { label: 'Kubernetes', to: '/', icon: Cpu, activeMatch: () => false },
    { label: 'Volume', to: '/', icon: Box, activeMatch: () => false },
    { label: 'Buckets', to: '/', icon: FolderArchive, activeMatch: () => false },
    { label: 'OSCraft AI', to: '/', icon: Sparkles, activeMatch: () => false },
  ]

  const navOrganize = [
    { label: 'Zero-Reboot (kexec)', to: '/kexec', icon: RefreshCw, activeMatch: (p: string) => p.startsWith('/kexec') },
    { label: 'Kernel API & IPC', to: '/settings', icon: Code2, activeMatch: () => false },
    { label: 'Settings', to: '/settings', icon: Settings, activeMatch: (p: string) => p.startsWith('/settings') },
  ]

  return (
    <div className="h-screen w-screen overflow-hidden flex flex-row bg-white text-slate-800 font-sans antialiased selection:bg-blue-500/20">
      {/* Left Sidebar (Desktop Application Frame) */}
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
                    <Icon className={`size-4 ${isActive ? 'text-blue-600' : 'text-slate-400'}`} />
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
                    <Icon className={`size-4 ${isActive ? 'text-blue-600' : 'text-slate-400'}`} />
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

      {/* Main Desktop Stage */}
      <div className="flex-1 h-full flex flex-col min-w-0 bg-[#fafbfc]">
        {/* Top Header Bar */}
        <header className="h-16 px-6 lg:px-8 border-b border-slate-200/70 bg-white/95 backdrop-blur-md flex items-center justify-between gap-4 shrink-0 z-10">
          {/* Search Pill Input */}
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search any resource, disk, or symbol..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-10 pr-4 py-2 rounded-full bg-slate-100/70 border border-slate-200/70 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:bg-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/15 transition-all duration-150"
            />
          </div>

          {/* Right Action & User Profile Cluster */}
          <div className="flex items-center gap-3">
            <div className="hidden sm:flex items-center gap-2.5 mr-2">
              <span className="text-xs font-bold text-slate-800">Apex</span>
              <div className="size-8 rounded-full bg-blue-600 text-white flex items-center justify-center font-bold text-xs shadow-2xs">
                A
              </div>
            </div>

            {/* Notification Bell */}
            <button
              className="relative p-2 rounded-full text-slate-500 hover:text-slate-800 hover:bg-slate-100 transition-colors duration-150 cursor-pointer active:scale-95"
              title="Kernel notifications"
            >
              <Bell className="size-4" />
              <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-red-500 ring-2 ring-white" />
            </button>

            {/* Live Terminal / Console */}
            <Link
              to="/kexec"
              className="p-2 rounded-full text-slate-500 hover:text-slate-800 hover:bg-slate-100 transition-colors duration-150 active:scale-95"
              title="Kernel console"
            >
              <Terminal className="size-4" />
            </Link>

            {/* Settings Cog */}
            <Link
              to="/settings"
              className="p-2 rounded-full text-slate-500 hover:text-slate-800 hover:bg-slate-100 transition-colors duration-150 active:scale-95"
              title="Settings"
            >
              <Settings className="size-4" />
            </Link>
          </div>
        </header>

        {/* Dedicated Internal Scroll Area */}
        <main className="flex-1 overflow-y-auto px-6 py-6 lg:px-8 lg:py-7">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
