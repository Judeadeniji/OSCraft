import { createRootRoute, Outlet } from '@tanstack/react-router'
import { Sidebar } from '@/components/layout/Sidebar'
import { Header } from '@/components/layout/Header'

export const Route = createRootRoute({
  component: RootComponent,
})

function RootComponent() {
  return (
    <div className="h-screen w-screen overflow-hidden flex flex-row bg-white text-slate-800 font-sans antialiased selection:bg-blue-500/20">
      {/* Left Sidebar Frame */}
      <Sidebar />

      {/* Main Desktop Stage */}
      <div className="flex-1 h-full flex flex-col min-w-0 bg-[#fafbfc]">
        <Header />

        {/* Dedicated Internal Scroll Area */}
        <main className="flex-1 overflow-y-auto px-6 py-6 lg:px-8 lg:py-7">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
