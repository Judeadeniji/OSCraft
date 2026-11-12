import { ArrowUpRight } from '@phosphor-icons/react'

export function UpcomingServices() {
  const services = [
    {
      title: 'Volumes',
      badge: 'BETA',
      description: 'Add volume storage to increase your storage space in a seconds',
      action: 'Configure Volume',
    },
    {
      title: 'Buckets',
      badge: 'BETA',
      description: 'Add buckets storage to increase your storage space in a seconds',
      action: 'Manage Buckets',
    },
    {
      title: 'Simply AI',
      badge: 'BETA',
      description: 'Glimps to add storage to increase your storage space in a seconds',
      action: 'Explore AI Tools',
    },
  ]

  return (
    <div className="space-y-3.5">
      <div className="px-1">
        <h2 className="text-sm font-bold text-slate-800 tracking-tight">Upcoming Services</h2>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {services.map((item) => (
          <div
            key={item.title}
            className="rounded-2xl border border-slate-200/70 bg-white shadow-2xs hover:shadow-xs hover:border-slate-300 p-5 transition-all duration-200 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center gap-2 mb-2.5">
                <span className="font-bold text-sm text-slate-900">{item.title}</span>
                <span className="bg-orange-500 text-white font-bold text-[10px] px-2 py-0.5 rounded-full tracking-wider shadow-2xs">
                  {item.badge}
                </span>
              </div>
              <p className="text-xs text-slate-500 leading-relaxed">{item.description}</p>
            </div>
            <button className="group mt-4 flex items-center justify-between w-full p-2 rounded-xl bg-slate-50 hover:bg-blue-50 text-slate-700 hover:text-blue-600 font-semibold text-xs transition-all duration-200 active:scale-[0.98] cursor-pointer">
              <span>{item.action}</span>
              <span className="size-6 rounded-full bg-white shadow-2xs flex items-center justify-center text-slate-400 group-hover:text-blue-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all duration-200">
                <ArrowUpRight className="size-3.5" weight="bold" />
              </span>
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
