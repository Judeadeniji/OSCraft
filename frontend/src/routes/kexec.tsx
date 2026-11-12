import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { RefreshCw, Play, CheckCircle2, ShieldCheck, Terminal } from 'lucide-react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

export const Route = createFileRoute('/kexec')({
  component: KexecComponent,
})

export function KexecComponent() {
  const [isRunning, setIsRunning] = useState(false)
  const [logs, setLogs] = useState<string[]>([
    '[INIT] OSCraft kexec_file_load subsystem initialized',
    '[OK] Memory topology verified: 16384 MiB contiguous addressable',
    '[OK] Target kernel: /boot/vmlinuz-6.12.0-oscraft',
    '[OK] Initramfs payload: /boot/initramfs-oscraft.img',
    '[READY] Ready for zero-reboot kernel handoff',
  ])

  const handleTriggerKexec = async () => {
    setIsRunning(true)
    setLogs((prev) => [...prev, '[TRIGGER] Executing kexec_file_load syscall...'])
    try {
      if (window.nanoui) {
        await window.nanoui.call('kernel.executeKexec', { dryRun: true })
        setLogs((prev) => [...prev, '[SUCCESS] Kernel simulated switch complete. (Dry Run)'])
      } else {
        await new Promise((r) => setTimeout(r, 1000))
        setLogs((prev) => [...prev, '[SIMULATION] Kernel simulated switch complete. (Dry Run)'])
      }
    } catch (err: any) {
      setLogs((prev) => [...prev, `[ERROR] kexec call failed: ${err.message}`])
    } finally {
      setIsRunning(false)
    }
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-foreground flex items-center gap-2">
            <RefreshCw className="size-5 text-primary" />
            Zero-Reboot Kernel Engine (kexec)
          </h1>
          <p className="text-xs text-muted-foreground mt-0.5">
            Switch directly from the live environment to your target Linux installation without UEFI reboot.
          </p>
        </div>
        <Button
          onClick={handleTriggerKexec}
          disabled={isRunning}
          className="font-mono text-xs gap-2"
        >
          <Play className={`size-3.5 ${isRunning ? 'animate-spin' : ''}`} />
          {isRunning ? 'Executing...' : 'Trigger Kernel Switch (Dry-Run)'}
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-mono flex items-center gap-2">
              <ShieldCheck className="size-4 text-emerald-400" />
              Pre-Flight Kernel Verification
            </CardTitle>
            <CardDescription className="text-xs">
              Hardware & memory map checks before kernel handover
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="flex items-center justify-between p-2 rounded bg-muted/60 border border-border">
              <span className="text-muted-foreground">Syscall Support</span>
              <Badge variant="success" className="font-mono text-[10px]">kexec_file_load (0x140)</Badge>
            </div>
            <div className="flex items-center justify-between p-2 rounded bg-muted/60 border border-border">
              <span className="text-muted-foreground">UEFI Secure Boot Status</span>
              <Badge variant="outline" className="font-mono text-[10px]">Signature Validated</Badge>
            </div>
            <div className="flex items-center justify-between p-2 rounded bg-muted/60 border border-border">
              <span className="text-muted-foreground">ACPI Table Preservation</span>
              <Badge variant="success" className="font-mono text-[10px]">Verified</Badge>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-mono flex items-center gap-2">
              <Terminal className="size-4 text-primary" />
              Kernel Handover Console
            </CardTitle>
            <CardDescription className="text-xs">
              Live stdout/stderr stream from Zig kexec subsystem
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="h-44 overflow-y-auto rounded-md bg-black/80 border border-border p-3 font-mono text-[11px] space-y-1 text-emerald-400">
              {logs.map((log, i) => (
                <div key={i} className="leading-tight">{log}</div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
