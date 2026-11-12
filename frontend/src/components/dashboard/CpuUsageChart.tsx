export function CpuUsageChart() {
  const months = [
    { month: 'Jan', height: '45%' },
    { month: 'Feb', height: '65%' },
    { month: 'Mar', height: '35%' },
    { month: 'Apr', height: '80%' },
    { month: 'May', height: '55%' },
    { month: 'Jun', height: '90%' },
  ]

  return (
    <div className="space-y-3 pt-1">
      <div className="flex items-center justify-between">
        <div className="text-xs font-bold text-slate-800">CPU Usage</div>
      </div>

      {/* Legend */}
      <div className="flex items-center gap-3 text-[11px] font-medium text-slate-600">
        <span className="flex items-center gap-1.5">
          <span className="size-2 rounded-full bg-slate-800" />
          All
        </span>
        <span className="flex items-center gap-1.5">
          <span className="size-2 rounded-full bg-slate-400" />
          Applications
        </span>
        <span className="flex items-center gap-1.5">
          <span className="size-2 rounded-full bg-blue-600" />
          Performance
        </span>
      </div>

      {/* Vertical Stick / Lollipop Chart */}
      <div className="bg-slate-50/80 rounded-2xl p-5 border border-slate-200/60 shadow-2xs">
        <div className="h-28 flex items-end justify-between gap-3 pt-2">
          {months.map((item) => (
            <div
              key={item.month}
              className="flex-1 flex flex-col items-center gap-2 h-full justify-end group cursor-pointer"
            >
              <div
                className="relative flex flex-col items-center transition-transform duration-200 group-hover:scale-110"
                style={{ height: item.height }}
              >
                {/* Blue Bead Top */}
                <div className="size-2 rounded-full bg-blue-600 shadow-2xs group-hover:bg-blue-500" />
                {/* Thin Line Stick */}
                <div className="w-0.5 flex-1 bg-slate-300 group-hover:bg-blue-300 transition-colors" />
              </div>
              <span className="text-[11px] text-slate-500 font-medium group-hover:text-slate-800 transition-colors">
                {item.month}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
