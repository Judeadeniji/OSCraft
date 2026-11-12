import { Link } from '@tanstack/react-router'
import { MagnifyingGlass, Bell, TerminalWindow, Gear } from '@phosphor-icons/react'
import { useState } from 'react'

export function Header() {
  const [searchQuery, setSearchQuery] = useState('')

  return (
    <header className="h-16 px-6 lg:px-8 border-b border-slate-200/70 bg-white/95 backdrop-blur-md flex items-center justify-between gap-4 shrink-0 z-10 select-none">
      {/* Search Pill Input */}
      <div className="relative flex-1 max-w-md">
        <MagnifyingGlass className="absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-slate-400" weight="regular" />
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
          <Bell className="size-4.5" weight="regular" />
          <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-red-500 ring-2 ring-white" />
        </button>

        {/* Live Terminal / Console */}
        <Link
          to="/kexec"
          className="p-2 rounded-full text-slate-500 hover:text-slate-800 hover:bg-slate-100 transition-colors duration-150 active:scale-95"
          title="Kernel console"
        >
          <TerminalWindow className="size-4.5" weight="regular" />
        </Link>

        {/* Settings Cog */}
        <Link
          to="/settings"
          className="p-2 rounded-full text-slate-500 hover:text-slate-800 hover:bg-slate-100 transition-colors duration-150 active:scale-95"
          title="Settings"
        >
          <Gear className="size-4.5" weight="regular" />
        </Link>
      </div>
    </header>
  )
}
