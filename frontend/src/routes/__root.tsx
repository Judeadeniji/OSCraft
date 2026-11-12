import { createRootRoute, Link, Outlet } from '@tanstack/react-router'
import { HardDrive, RefreshCw, Settings, ShieldAlert, Cpu } from 'lucide-react'
import { Badge } from '@/components/ui/badge'

export const Route = createRootRoute({
  component: RootComponent,
})

function RootComponent() {
  return (
    <div className="flex h-screen w-screen flex-col bg-background text-foreground antialiased selection:bg-primary/30">
      {/* Top Navigation Bar */}
      <header className="flex h-14 shrink-0 items-center justify-between border-b border-border px-4 bg-card/60 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <div className="flex items-center justify-center size-8 rounded-lg bg-primary/20 border border-primary/30 text-primary">
            <Cpu className="size-4" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="font-mono font-bold tracking-tight text-foreground">OSCraft</span>
            <span className="text-xs text-muted-foreground font-mono">v0.1.0-alpha</span>
          </div>
          <Badge variant="success" className="ml-2 font-mono text-[10px]">
            NANOUI WEBVIEW
          </Badge>
        </div>

        <nav className="flex items-center gap-1">
          <Link
            to="/"
            className="flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium text-muted-foreground hover:text-foreground hover:bg-accent transition-colors [&.active]:bg-secondary [&.active]:text-foreground"
          >
            <HardDrive className="size-3.5" />
            Disks & Topology
          </Link>
          <Link
            to="/kexec"
            className="flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium text-muted-foreground hover:text-foreground hover:bg-accent transition-colors [&.active]:bg-secondary [&.active]:text-foreground"
          >
            <RefreshCw className="size-3.5" />
            Zero-Reboot (kexec)
          </Link>
          <Link
            to="/settings"
            className="flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium text-muted-foreground hover:text-foreground hover:bg-accent transition-colors [&.active]:bg-secondary [&.active]:text-foreground"
          >
            <Settings className="size-3.5" />
            Settings
          </Link>
        </nav>

        <div className="flex items-center gap-2">
          <Badge variant="outline" className="font-mono text-[10px] text-muted-foreground border-border flex items-center gap-1.5">
            <span className="size-1.5 rounded-full bg-emerald-400 animate-pulse" />
            KERNEL ONLINE
          </Badge>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 overflow-auto p-6">
        <Outlet />
      </main>
    </div>
  )
}
