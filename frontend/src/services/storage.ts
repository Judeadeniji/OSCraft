import { Disk } from '@/types/storage'

export const DEFAULT_DISKS: Disk[] = [
  {
    path: '/dev/nvme0n1',
    model: 'Samsung SSD 990 PRO 2TB',
    sizeBytes: 2000398934016,
    tableType: 'GPT',
    ipAddress: '50.3.80.29',
    enabled: true,
    partitions: [
      {
        name: '/dev/nvme0n1p1',
        label: 'EFI System',
        fsType: 'vfat',
        sizeBytes: 1073741824,
        mountPoint: '/boot/efi',
        isBoot: true,
      },
      {
        name: '/dev/nvme0n1p2',
        label: 'OSCraft-Root',
        fsType: 'btrfs',
        sizeBytes: 1999325192192,
        mountPoint: '/',
        isBoot: false,
      },
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
      {
        name: '/dev/sda1',
        label: 'LIVE-BOOT',
        fsType: 'ext4',
        sizeBytes: 31998951424,
        mountPoint: '/run/live',
        isBoot: true,
      },
    ],
  },
]

export const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KiB', 'MiB', 'GiB', 'TiB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`
}

export async function probeDisksLoader(): Promise<Disk[]> {
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
