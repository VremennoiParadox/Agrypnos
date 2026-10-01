// Native smoke observer: the production plugin owns the actual answer path.
import { writeFileSync } from "node:fs"
export default {
  id: "agrypnos-production-smoke",
  tui: async api => {
    const { createOpenCodeBridge } = await import(process.env.AGRYPNOS_PRODUCT_MODULE)
    const bridge = createOpenCodeBridge(api, { manifestPath: process.env.AGRYPNOS_PRODUCT_MANIFEST })
    const report = { hostVersion: api.app.version, questionReply: true, pendingListed: false, markerCount: 0 }
    const save = () => writeFileSync(process.env.AGRYPNOS_PROBE_OUTPUT, JSON.stringify(report), { mode: 0o600 })
    api.lifecycle.onDispose(() => { bridge.dispose(); report.disposed = true; save() })
    api.event.on("question.asked", async ({ properties }) => {
      report.originalSessionID = properties.sessionID; report.originalRequestID = properties.id
      const pending = await api.client.question.list({ directory: api.state.path.directory })
      report.pendingListed = pending.data?.some(q => q.id === properties.id && q.sessionID === properties.sessionID)
      save()
    })
    api.event.on("session.idle", async ({ properties }) => {
      if (properties.sessionID !== report.originalSessionID) return
      const messages = await api.client.session.messages({ sessionID: properties.sessionID, directory: api.state.path.directory })
      report.markerCount = (messages.data ?? []).flatMap(m => m.parts ?? [])
        .filter(p => p.type === "text" && p.text === process.env.AGRYPNOS_PROBE_MARKER).length
      if (report.markerCount) report.continuedSessionID = properties.sessionID
      save()
    })
    save()
  },
}
