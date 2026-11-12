import { Disk } from '@/types/storage'
import { formatBytes } from '@/services/storage'

interface TopologyBarProps {
  disk: Disk
}

export function TopologyBar({ disk }: TopologyBarProps) {
  return (
    <div className="px-5 pb-5 pt-2 border-t border-slate-100 bg-slate-50/50 space-y-4">
      {/* Visual Sector Bar */}
      <div>
        <div className="flex items-center justify-between text-[11px] font-semibold text-slate-600 mb-2">
          <span>SECTOR ALLOCATION : {disk.model}</span>
          <span><code>{formatBytes(disk.sizeBytes)} ({disk.tableType})</code></span>
        </div>
        <div className="h-7 w-full rounded-xl overflow-hidden bg-slate-200 flex p-1 gap-1 border border-slate-200/80">
          {disk.partitions.map((part) => {
            const pct = Math.max(15, (part.sizeBytes / disk.sizeBytes) * 100)
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
            {disk.partitions.map((p) => (
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
  )
}
