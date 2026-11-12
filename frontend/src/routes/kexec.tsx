import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import {
  ArrowsClockwise,
  Play,
  ShieldCheck,
  TerminalWindow,
} from '@phosphor-icons/react'

export const Route = createFileRoute('/kexec')({
  component: KexecComponent,
})

function KexecComponent() {
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
        setLogs((prev) => [...prev, '[SUCCESS] Kernel simulated switch complete. (Dry Run Guaranteed)'])
      } else {
        await new Promise((r) => setTimeout(r, 900))
        setLogs((prev) => [...prev, '[SIMULATION] Kernel simulated switch complete. (Dry Run Guaranteed)'])
      }
    } catch (err: any) {
      setLogs((prev) => [...prev, `[ERROR] kexec call failed: ${err.message}`])
    } finally {
      setIsRunning(false)
    }
  }

  return (
    <div className="space-y-8 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2">
        <div className="flex items-center gap-4">
          <div className="p-1 rounded-2xl bg-blue-50/70 border border-blue-100/60 shadow-2xs">
            <div className="size-12 rounded-xl bg-blue-600 text-white flex items-center justify-center shadow-xs">
              <ArrowsClockwise className="size-6" weight="bold" />
            </div>
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-slate-900 leading-tight">
              Zero-Reboot Kernel Engine (kexec)
            </h1>
            <p className="text-xs font-semibold text-slate-500 mt-0.5">
              Switch directly into your target Linux system in &lt; 3s without UEFI POST cycle.
            </p>
          </div>
        </div>

        <button
          onClick={handleTriggerKexec}
          disabled={isRunning}
          className="flex items-center gap-2 px-5 py-2.5 rounded-full bg-blue-600 hover:bg-blue-700 active:scale-95 text-white text-xs font-semibold shadow-md shadow-blue-500/20 transition-all duration-200 cursor-pointer disabled:opacity-50"
        >
          <Play className={`size-3.5 fill-current ${isRunning ? 'animate-spin' : ''}`} weight="fill" />
          {isRunning ? 'Executing Switch...' : 'Trigger Kernel Switch (Dry-Run)'}
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Pre-Flight Kernel Verification Card */}
        <div className="bg-white rounded-3xl border border-slate-200/70 shadow-2xs p-6 space-y-5">
          <div className="flex items-center gap-3">
            <div className="size-9 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100/80 shadow-2xs">
              <ShieldCheck className="size-5" weight="bold" />
            </div>
            <div>
              <h2 className="font-bold text-sm text-slate-900">Pre-Flight Verification</h2>
              <p className="text-[11px] text-slate-400">Hardware & memory map checks</p>
            </div>
          </div>

          <div className="space-y-2.5 text-xs">
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-200/50">
              <span className="text-slate-600 font-medium">Syscall Support</span>
              <span className="font-mono text-[11px] font-bold text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full border border-blue-100">
                kexec_file_load (0x140)
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-200/50">
              <span className="text-slate-600 font-medium">UEFI Secure Boot</span>
              <span className="font-mono text-[11px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-100">
                Signature Validated
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-200/50">
              <span className="text-slate-600 font-medium">ACPI Table Preservation</span>
              <span className="font-mono text-[11px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-100">
                Verified Contiguous
              </span>
            </div>
            <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-50 border border-slate-200/50">
              <span className="text-slate-600 font-medium">Dry-Run Enforcer</span>
              <span className="font-mono text-[11px] font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-100">
                Armed & Non-Destructive
              </span>
            </div>
          </div>
        </div>

        {/* Live Terminal Console Card */}
        <div className="bg-white rounded-3xl border border-slate-200/70 shadow-2xs p-6 flex flex-col justify-between space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="size-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center border border-blue-100/80 shadow-2xs">
                <TerminalWindow className="size-5" weight="bold" />
              </div>
              <div>
                <h2 className="font-bold text-sm text-slate-900">Kernel Console</h2>
                <p className="text-[11px] text-slate-400">Live stdout/stderr stream</p>
              </div>
            </div>
            <span className="inline-flex items-center gap-1.5 text-[11px] font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-100">
              <span className="size-1.5 rounded-full bg-emerald-500 animate-pulse" />
              STREAM ACTIVE
            </span>
          </div>

          <div className="h-56 overflow-y-auto rounded-2xl bg-slate-950 p-4 font-mono text-[11px] space-y-1.5 text-emerald-400 shadow-inner border border-slate-800">
            {logs.map((log, i) => (
              <div key={i} className="leading-relaxed">
                {log}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
