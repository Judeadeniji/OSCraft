import { createFileRoute, useRouter } from '@tanstack/react-router'
import { useState } from 'react'
import { ProjectHeader } from '@/components/dashboard/ProjectHeader'
import { StackletCard } from '@/components/dashboard/StackletCard'
import { KubernetesCard } from '@/components/dashboard/KubernetesCard'
import { UpcomingServices } from '@/components/dashboard/UpcomingServices'
import { PerformanceOverview } from '@/components/dashboard/PerformanceOverview'
import { probeDisksLoader } from '@/services/storage'
import { Disk, TabType } from '@/types/storage'

export const Route = createFileRoute('/')({
  loader: async () => probeDisksLoader(),
  component: DiskManagerComponent,
})

function DiskManagerComponent() {
  const router = useRouter()
  const initialDisks = Route.useLoaderData()
  const [activeTab, setActiveTab] = useState<TabType>('resources')
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
        <ProjectHeader
          activeTab={activeTab}
          onSelectTab={setActiveTab}
          onRefresh={handleRefresh}
          isRefreshing={isRefreshing}
        />

        {/* Section 1: Stacklets */}
        <div className="space-y-3.5">
          <div className="flex items-center justify-between px-1">
            <h2 className="text-sm font-bold text-slate-800 tracking-tight">Stacklets</h2>
            <span className="text-xs font-semibold text-slate-500">
              {disks.length} Block Devices Active
            </span>
          </div>

          <div className="space-y-3">
            {disks.map((disk) => (
              <StackletCard
                key={disk.path}
                disk={disk}
                isExpanded={expandedDisk === disk.path}
                onToggleExpand={() =>
                  setExpandedDisk(expandedDisk === disk.path ? null : disk.path)
                }
                onToggleEnabled={() => toggleDisk(disk.path)}
              />
            ))}
          </div>
        </div>

        {/* Section 2: Kubernetes */}
        <KubernetesCard />

        {/* Section 3: Upcoming Services */}
        <UpcomingServices />
      </div>

      {/* Right Column: Performance Overview */}
      <div className="xl:col-span-4">
        <PerformanceOverview />
      </div>
    </div>
  )
}
