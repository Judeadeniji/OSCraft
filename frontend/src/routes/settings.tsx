import { createFileRoute } from '@tanstack/react-router'
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

export const Route = createFileRoute('/settings')({
  component: SettingsComponent,
})

export function SettingsComponent() {
  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      <div>
        <h1 className="text-xl font-bold tracking-tight text-foreground">Settings & Environment</h1>
        <p className="text-xs text-muted-foreground mt-0.5">
          Runtime parameters, nanoui IPC bridge diagnostics, and styling configuration.
        </p>
      </div>

      <div className="grid gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-mono">Frontend Toolchain</CardTitle>
            <CardDescription className="text-xs">Active stack versions and configurations</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="flex items-center justify-between py-1.5 border-b border-border/60">
              <span className="text-muted-foreground">Package Manager</span>
              <Badge variant="outline">Bun 1.4.x</Badge>
            </div>
            <div className="flex items-center justify-between py-1.5 border-b border-border/60">
              <span className="text-muted-foreground">UI Framework</span>
              <Badge variant="outline">React 19 + TypeScript</Badge>
            </div>
            <div className="flex items-center justify-between py-1.5 border-b border-border/60">
              <span className="text-muted-foreground">Routing</span>
              <Badge variant="outline">TanStack Router (File-based)</Badge>
            </div>
            <div className="flex items-center justify-between py-1.5 border-b border-border/60">
              <span className="text-muted-foreground">CSS Engine</span>
              <Badge variant="outline">Tailwind CSS v4 (@tailwindcss/vite)</Badge>
            </div>
            <div className="flex items-center justify-between py-1.5 border-b border-border/60">
              <span className="text-muted-foreground">Component Library</span>
              <Badge variant="outline">shadcn/ui</Badge>
            </div>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-muted-foreground">Backend Bridge</span>
              <Badge variant="success">nanoui System Webview IPC</Badge>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
