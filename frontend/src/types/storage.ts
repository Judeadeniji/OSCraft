export interface Partition {
  name: string
  label: string
  fsType: string
  sizeBytes: number
  mountPoint?: string
  isBoot: boolean
}

export interface Disk {
  path: string
  model: string
  sizeBytes: number
  tableType: 'GPT' | 'MBR' | 'RAW'
  ipAddress?: string
  enabled?: boolean
  partitions: Partition[]
}

export type TabType = 'resources' | 'member' | 'setting'
