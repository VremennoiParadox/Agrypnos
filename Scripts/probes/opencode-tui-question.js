// Disposable native probe; never bundled. Only public terminal-plugin APIs.
import { writeFileSync } from "node:fs"
import { randomUUID } from "node:crypto"
import { createConnection } from "node:net"

export default {
  id: "agrypnos-tui-feasibility",
  tui: async (api) => {
    const output = process.env.AGRYPNOS_PROBE_OUTPUT
    if (!output) return
    const mode = process.env.AGRYPNOS_PROBE_MODE ?? "ordinary"
    const marker = process.env.AGRYPNOS_PROBE_MARKER
    const report = {
      hostVersion: api.app.version,
      instanceID: randomUUID(),
      directory: api.state.path.directory,
      questionReply: typeof api.client.question?.reply === "function",
      questionList: typeof api.client.question?.list === "function",
      nodeNetAvailable: typeof createConnection === "function",
      originalSessionID: null, originalRequestID: null, continuedSessionID: null,
      replyAttempts: 0, markerCount: 0, pendingListed: false,
      requiresExplicitListener: false, resolutionBeforeAcknowledgmentObserved: false,
      acceptedBeforeAcknowledgment: false, accepted: false, disposed: false,
    }
    const save = () => writeFileSync(output, JSON.stringify(report, null, 2), { mode: 0o600 })
    save()
    api.lifecycle.onDispose(() => { report.disposed = true; save() })
    if (!report.questionReply || !report.questionList) return
    const pending = await api.client.question.list({ directory: report.directory })
    report.initialPendingCount = pending.data?.length
    save()
    api.event.on("question.replied", ({ properties }) => {
      if (properties.requestID !== report.originalRequestID) return
      report.resolutionBeforeAcknowledgmentObserved = !report.accepted
      save()
    })
    api.event.on("question.asked", async ({ properties }) => {
      if (report.originalRequestID) return
      report.originalRequestID = properties.id
      report.originalSessionID = properties.sessionID
      const list = await api.client.question.list({ directory: report.directory })
      report.pendingListed = list.data?.some(q => q.id === properties.id && q.sessionID === properties.sessionID)
      save()
      if (mode === "unavailable") {
        report.localPromptAvailable = api.state.session.question(properties.sessionID).some(q => q.id === properties.id)
        const socket = createConnection({ path: output + ".absent.sock" })
        socket.on("error", () => { report.ipcUnavailableObserved = true; socket.destroy(); save() })
        save()
        return
      }
      if (mode === "local") {
        // An independent supported native API answer wins before remote submission.
        const winner = await api.client.question.reply({ requestID: properties.id,
          directory: report.directory, answers: [["B"]] })
        const remaining = await api.client.question.list({ directory: report.directory })
        report.localResolutionObserved = winner.data === true && !remaining.data?.some(q => q.id === properties.id)
        report.accepted = winner.data === true
        save()
        return
      }
      report.replyAttempts++
      save()
      const result = await api.client.question.reply({
        requestID: properties.id, directory: report.directory, answers: [["B"]],
      })
      report.accepted = result.data === true && result.response?.status === 200
      report.replyStatus = result.response?.status
      save()
    })
    api.event.on("session.idle", async ({ properties }) => {
      if (properties.sessionID !== report.originalSessionID) return
      const result = await api.client.session.messages({ sessionID: properties.sessionID, directory: report.directory })
      const messages = result.data ?? []
      report.markerCount = messages.flatMap(m => m.parts ?? []).filter(p => p.type === "text" && p.text === marker).length
      if (report.markerCount) report.continuedSessionID = properties.sessionID
      save()
    })
  },
}
