import { createFileRoute } from '@tanstack/react-router'
import { useState, useEffect } from 'react'
import { HardDrive, RefreshCw, AlertTriangle, Play, Database, Layers } from 'lucide-react'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

export const Route = createFileRoute('/')({
  component: DiskManagerComponent,
})

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
  partitions: Partition[]
}

const formatBytes = (bytes: number) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`
}

export function DiskManagerComponent() {
  const [disks, setDisks] = useState<Disk[]>([
    {
      path: '/dev/nvme0n1',
      model: 'Samsung SSD 990 PRO 2TB',
      sizeBytes: 2000398934016,
      tableType: 'GPT',
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
      partitions: [
        { name: '/dev/sda1', label: 'LIVE-BOOT', fsType: 'ext4', sizeBytes: 31998951424, mountPoint: '/run/live', isBoot: true },
      ],
    },
  ])
  const [selectedDisk, setSelectedDisk] = useState<string>('/dev/nvme0n1')
  const [isRefreshing, setIsRefreshing] = useState(false)

  const activeDisk = disks.find((d) => d.path === selectedDisk) || disks[0]

  const handleRefresh = async () => {
    setIsRefreshing(true)
    try {
      if (window.nanoui) {
        const probed = await window.nanoui.call<Disk[]>('storage.probeDisks')
        if (probed && probed.length > 0) {
          setDisks(probed)
        }
      } else {
        // Fallback for standalone browser testing
        await new Promise((r) => setTimeout(r, 600))
      }
    } catch (err) {
      console.warn('IPC probe failed:', err)
    } finally {
      setIsRefreshing(false)
    }
  }

  useEffect(() => {
    handleRefresh()

    // Listen for live disk hotplug events from Zig
    if (window.nanoui) {
      const unbind = window.nanoui.on('storage.topologyChanged', () => {
        handleRefresh()
      })
      return () => unbind()
    }
  }, [])

  return (
    <div className="space-y-6 max-w-7xl mx-auto">
      {/* Top Header Actions */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-foreground flex items-center gap-2">
            <Layers className="size-5 text-primary" />
            Storage Topology & Live Partitioning
          </h1>
          <p className="text-xs text-muted-foreground mt-0.5">
            Non-destructive partition alignment, Btrfs subvolumes, and kernel mounts.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="font-mono text-xs"
          >
            <RefreshCw className={`size-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
            Rescan Disks
          </Button>
          <Button size="sm" className="font-mono text-xs">
            <Play className="size-3.5" />
            Apply Plan
          </Button>
        </div>
      </div>

      {/* Disks Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Disks List Sidebar */}
        <div className="space-y-3">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground font-mono">
            Discovered Devices ({disks.length})
          </h2>
          <div className="space-y-2">
            {disks.map((d) => {
              const isSelected = d.path === selectedDisk
              return (
                <div
                  key={d.path}
                  onClick={() => setSelectedDisk(d.path)}
                  className={`p-3 rounded-lg border text-left cursor-pointer transition-all ${
                    isSelected
                      ? 'border-primary/50 bg-secondary/80 ring-1 ring-primary/40'
                      : 'border-border bg-card/40 hover:bg-card hover:border-muted-foreground/30'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="font-mono text-xs font-bold text-foreground flex items-center gap-1.5">
                      <HardDrive className="size-3.5 text-muted-foreground" />
                      {d.path}
                    </span>
                    <Badge variant="outline" className="font-mono text-[10px]">
                      {d.tableType}
                    </Badge>
                  </div>
                  <div className="text-xs text-foreground truncate">{d.model}</div>
                  <div className="flex items-center justify-between mt-2 text-[11px] text-muted-foreground font-mono">
                    <span>{formatBytes(d.sizeBytes)}</span>
                    <span>{d.partitions.length} partitions</span>
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {/* Selected Disk Topology Detail */}
        <div className="md:col-span-2 space-y-4">
          {activeDisk ? (
            <>
              <Card>
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between">
                    <div>
                      <CardTitle className="font-mono text-base">{activeDisk.path}</CardTitle>
                      <CardDescription className="text-xs mt-1">
                        {activeDisk.model} — Total Capacity: {formatBytes(activeDisk.sizeBytes)}
                      </CardDescription>
                    </div>
                    <Badge variant="success" className="font-mono text-xs">
                      HEALTHY
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* Visual Partition Bar */}
                  <div>
                    <div className="text-xs font-semibold text-muted-foreground font-mono mb-2">
                      SECTOR ALLOCATION
                    </div>
                    <div className="h-8 w-full rounded-md overflow-hidden bg-muted flex p-0.5 gap-1 border border-border">
                      {activeDisk.partitions.map((part) => {
                        const pct = Math.max(8, (part.sizeBytes / activeDisk.sizeBytes) * 100)
                        return (
                          <div
                            key={part.name}
                            style={{ width: `${pct}%` }}
                            className={`h-full rounded-sm flex items-center justify-center px-2 text-[10px] font-mono font-bold truncate transition-opacity hover:opacity-80 cursor-pointer ${
                              part.fsType === 'vfat'
                                ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                                : part.fsType === 'btrfs'
                                ? 'bg-primary/20 text-primary border border-primary/30'
                                : 'bg-blue-500/20 text-blue-300 border border-blue-500/30'
                            }`}
                            title={`${part.name} (${part.fsType}): ${formatBytes(part.sizeBytes)}`}
                          >
                            {part.name.split('/').pop()} ({part.fsType})
                          </div>
                        )
                      })}
                    </div>
                  </div>

                  {/* Partitions Table */}
                  <div className="border border-border rounded-md overflow-hidden font-mono text-xs">
                    <table className="w-full text-left">
                      <thead className="bg-muted/50 text-muted-foreground text-[11px] border-b border-border">
                        <tr>
                          <th className="py-2 px-3">Partition</th>
                          <th className="py-2 px-3">Label</th>
                          <th className="py-2 px-3">Filesystem</th>
                          <th className="py-2 px-3">Size</th>
                          <th className="py-2 px-3">Mount Point</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-border">
                        {activeDisk.partitions.map((part) => (
                          <tr key={part.name} className="hover:bg-accent/40">
                            <td className="py-2 px-3 font-bold text-foreground flex items-center gap-1.5">
                              <Database className="size-3 text-muted-foreground" />
                              {part.name}
                            </td>
                            <td className="py-2 px-3 text-muted-foreground">{part.label || '—'}</td>
                            <td className="py-2 px-3">
                              <span className="uppercase text-[10px] px-1.5 py-0.5 rounded bg-muted">
                                {part.fsType}
                              </span>
                            </td>
                            <td className="py-2 px-3">{formatBytes(part.sizeBytes)}</td>
                            <td className="py-2 px-3 text-primary">{part.mountPoint || 'Not mounted'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </CardContent>
              </Card>

              {/* Safety Assertions Panel */}
              <div className="p-4 rounded-lg border border-amber-500/20 bg-amber-500/5 flex items-start gap-3">
                <AlertTriangle className="size-4 text-amber-400 shrink-0 mt-0.5" />
                <div className="text-xs space-y-1">
                  <div className="font-semibold text-amber-300 font-mono">Kernel Guardrail Active</div>
                  <p className="text-muted-foreground">
                    Modifications run in dry-run simulation mode until explicitly verified and confirmed.
                    Live disk sectors are locked against accidental unaligned writes.
                  </p>
                </div>
              </div>
            </>
          ) : (
            <div className="p-8 text-center text-muted-foreground border border-dashed rounded-lg">
              No disk selected
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
