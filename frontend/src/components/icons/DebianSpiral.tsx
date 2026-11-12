interface DebianSpiralProps {
  className?: string
}

export function DebianSpiral({ className = 'size-5' }: DebianSpiralProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12.18 3.5c-4.69.09-8.48 3.96-8.38 8.66.08 4.34 3.45 7.92 7.77 8.25.82.06 1.3-.58 1.21-1.22-.07-.53-.4-1-.61-1.49-.31-.72-.45-1.52-.39-2.3.14-2.01 1.79-3.59 3.8-3.56.85.01 1.66.34 2.31.89.5.42 1.18.48 1.74.17.84-.46 1.04-1.53.45-2.26-1.57-1.94-4.55-4.73-7.9-4.64z" />
      <circle cx="9" cy="11.5" r="1.3" fill="white" />
    </svg>
  )
}
