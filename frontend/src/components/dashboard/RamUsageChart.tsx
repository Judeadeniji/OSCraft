export function RamUsageChart() {
  const bars = [
    { day: 'Sun', height: '42%' },
    { day: 'Mon', height: '58%' },
    { day: 'Tue', height: '72%' },
    { day: 'Wed', height: '62%' },
    { day: 'Thu', height: '90%', active: true, badge: '25%' },
    { day: 'Fri', height: '78%' },
    { day: 'Sat', height: '36%' },
  ]

  return (
    <div className="space-y-3">
      <div className="text-xs font-bold text-slate-800">RAM Usage</div>
      <div className="bg-slate-50/80 rounded-2xl p-5 border border-slate-200/60 shadow-2xs">
        <div className="h-32 flex items-end justify-between gap-2.5 pt-6 relative">
          {bars.map((b) => (
            <div
              key={b.day}
              className="flex-1 flex flex-col items-center gap-2 h-full justify-end relative"
            >
              {b.active && (
                <div className="absolute -top-4 bg-slate-900 text-white font-bold text-[10px] px-2 py-0.5 rounded-md shadow-xs animate-bounce">
                  {b.badge}
                </div>
              )}
              <div
                className={`w-full rounded-lg transition-all duration-300 ${
                  b.active
                    ? 'bg-slate-900 shadow-xs hover:bg-slate-800'
                    : 'bg-blue-100 hover:bg-blue-200'
                }`}
                style={{ height: b.height }}
              />
              <span
                className={`text-[11px] font-medium ${
                  b.active ? 'text-slate-900 font-bold' : 'text-slate-500'
                }`}
              >
                {b.day}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
