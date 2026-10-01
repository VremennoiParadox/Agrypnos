import { openSync, closeSync, readFileSync, lstatSync, fstatSync, watch, constants } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, basename } from "node:path"
import { createConnection } from "node:net"
import { randomUUID } from "node:crypto"

export const RETRY_SECONDS = [1, 2, 4, 8, 16, 30]
const LIMIT = 262144
const uuid = value => typeof value === "string" && /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value)
const schema = q => JSON.stringify(q.questions)
const identity = q => q.sessionID + "|" + q.id
const validQuestion = q => q && /^que_[a-zA-Z0-9]+$/.test(q.id) && typeof q.sessionID === "string" && q.sessionID.length > 0
  && Array.isArray(q.questions) && q.questions.length > 0 && q.questions.length <= 4
  && q.questions.every(p => typeof p.question === "string" && p.question.trim() && Array.isArray(p.options)
    && p.options.length > 0 && p.options.length <= 20
    && p.options.every(o => typeof o.label === "string" && o.label.trim())
    && new Set(p.options.map(o => o.label.trim())).size === p.options.length)

function privateDirectory(parent) {
  for (let current = parent; current !== dirname(current); current = dirname(current)) {
    if (lstatSync(current).isSymbolicLink()) throw new Error("Unsafe parent")
  }
  const directory = lstatSync(parent)
  if (directory.uid !== process.getuid() || (directory.mode & 0o077)) throw new Error("Unsafe directory")
  return parent
}

function readManifest(path) {
  // Nothing here protects against a compromised process running as the same user.
  const parent = privateDirectory(dirname(path))
  const fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK)
  try {
    const info = fstatSync(fd)
    if (!info.isFile() || info.uid !== process.getuid() || (info.mode & 0o077) || info.size > LIMIT) throw new Error("Unsafe manifest")
    const manifest = JSON.parse(readFileSync(fd, "utf8"))
    if (manifest.active !== true) return null
    if (manifest.protocolVersion !== 1 || !uuid(manifest.generation) || !/^[a-f0-9]{64}$/.test(manifest.token)
      || typeof manifest.socketPath !== "string" || !manifest.socketPath.startsWith("/")) throw new Error("Invalid manifest")
    privateDirectory(dirname(manifest.socketPath))
    const socket = lstatSync(manifest.socketPath)
    if (!socket.isSocket() || socket.uid !== process.getuid() || (socket.mode & 0o077)) throw new Error("Unsafe socket")
    return manifest
  } finally { closeSync(fd) }
}

export function createOpenCodeBridge(api, { manifestPath = join(homedir(), "Library/Application Support/Agrypnos/opencode-bridge/bridge.json") } = {}) {
  if (api.app.version !== "1.18.32" || typeof api.client.question?.reply !== "function"
    || typeof api.client.question?.list !== "function") return { dispose() {} }
  const instanceID = randomUUID(), directory = api.state.path.directory
  const records = new Map(), unsubscribers = []
  let socket, manifest, ready = false, disposed = false, retry, changed, watcher, retryIndex = 0
  let buffered = Buffer.alloc(0), connectionEpoch = 0, snapshotChanges
  const current = (peer, epoch) => !disposed && peer === socket && epoch === connectionEpoch
  const send = message => {
    if (!ready || !socket || socket.destroyed) return false
    const bytes = Buffer.from(JSON.stringify(message) + "\n")
    if (bytes.length > LIMIT || socket.writableLength + bytes.length > LIMIT) { socket.destroy(); return false }
    socket.write(bytes); return true
  }
  function schedule() {
    if (disposed || !manifest || retry) return
    retry = setTimeout(() => { retry = undefined; connect() }, RETRY_SECONDS[Math.min(retryIndex++, 5)] * 1000)
    retry.unref?.()
  }
  function refresh() {
    if (disposed) return
    let next
    try { next = readManifest(manifestPath) } catch { next = null }
    if (JSON.stringify(next) === JSON.stringify(manifest)) return
    connectionEpoch++; ready = false; socket?.destroy(); socket = undefined
    clearTimeout(retry); retry = undefined; records.clear(); snapshotChanges = undefined; retryIndex = 0; manifest = next
    if (manifest) connect()
  }
  function connect() {
    if (disposed || !manifest || socket) return
    const peer = createConnection({ path: manifest.socketPath }), epoch = ++connectionEpoch
    socket = peer; ready = false; buffered = Buffer.alloc(0)
    const handshakeTimeout = setTimeout(() => peer.destroy(), 2000); handshakeTimeout.unref?.()
    peer.on("connect", () => {
      if (!current(peer, epoch)) return
      peer.write(JSON.stringify({ type: "hello", protocolVersion: 1, token: manifest.token,
        instanceID, generation: manifest.generation, hostVersion: api.app.version, directory,
        projectLabel: basename(directory).slice(0, 256) || directory }) + "\n")
    })
    peer.on("data", bytes => {
      if (!current(peer, epoch)) return
      try {
        let start = 0
        for (let end = bytes.indexOf(10); end !== -1; end = bytes.indexOf(10, start)) {
          if (buffered.length + end - start + 1 > LIMIT) throw new Error("Oversized frame")
          const text = new TextDecoder("utf-8", { fatal: true }).decode(Buffer.concat([buffered, bytes.subarray(start, end)]))
          buffered = Buffer.alloc(0)
          const message = JSON.parse(text)
          if (!ready) {
            if (message.type !== "ready" || Object.keys(message).sort().join() !== "generation,type"
              || message.generation?.toLowerCase() !== manifest.generation.toLowerCase()) throw new Error("Unauthorized peer")
            ready = true; retryIndex = 0; clearTimeout(handshakeTimeout)
            void snapshot(peer, epoch)
          } else if (message.type === "reply") void reply(message, peer, epoch)
          else if (message.type === "local") {
            if (Object.keys(message).sort().join() !== "requestID,sessionID,type") throw new Error("Invalid local")
            const record = records.get(message.sessionID + "|" + message.requestID)
            if (record) record.attempted = true
          } else throw new Error("Invalid message")
          start = end + 1
        }
        const tail = bytes.subarray(start)
        if (buffered.length + tail.length >= LIMIT) throw new Error("Oversized frame")
        if (tail.length) buffered = Buffer.concat([buffered, tail])
      } catch { peer.destroy() }
    })
    peer.on("error", () => {})
    peer.on("close", () => {
      clearTimeout(handshakeTimeout)
      if (!current(peer, epoch)) return
      ready = false; socket = undefined; schedule()
    })
  }
  function snapshotEvent(key, original) {
    if (!snapshotChanges) return
    snapshotChanges.set(key, original)
    if (snapshotChanges.size > 64) socket?.destroy()
  }
  async function snapshot(peer, epoch) {
    const changes = new Map(); snapshotChanges = changes
    try {
      const response = await api.client.question.list({ directory })
      if (!current(peer, epoch) || !ready) return
      if (response.response?.status !== 200 || !Array.isArray(response.data) || response.data.length > 32) { peer.destroy(); return }
      const pending = new Map(response.data.filter(validQuestion).map(q => [identity(q), q]))
      // The list can predate events received while it was awaiting the native transport.
      for (const [key, original] of changes) {
        if (original) pending.set(key, original)
        else pending.delete(key)
      }
      if (pending.size > 32) { peer.destroy(); return }
      for (const key of records.keys()) if (!pending.has(key)) records.delete(key)
      send({ type: "snapshot", originals: [...pending.values()] })
    } catch { if (current(peer, epoch)) peer.destroy() }
    finally { if (snapshotChanges === changes) snapshotChanges = undefined }
  }
  async function reply(message, peer, epoch) {
    const key = message.sessionID + "|" + message.requestID, record = records.get(key)
    const result = delivery => { if (current(peer, epoch) && ready) send({ type: "result", attemptID: message.attemptID, delivery }) }
    if (Object.keys(message).sort().join() !== "answers,attemptID,requestID,sessionID,type" || !uuid(message.attemptID)) { peer.destroy(); return }
    const answers = message.answers
    if (!record || record.attempted || performance.now() >= record.deadline || !Array.isArray(answers)
      || answers.length !== record.original.questions.length
      || !answers.every((selected, i) => Array.isArray(selected) && selected.length > 0
        && (record.original.questions[i].multiple || selected.length === 1)
        && new Set(selected).size === selected.length
        && selected.every(label => record.original.questions[i].options.some(o => o.label === label)))) { result("rejected"); return }
    record.attempted = true // Reserve before either native await; a lost acknowledgment never retries.
    try {
      const pending = await api.client.question.list({ directory })
      if (!current(peer, epoch) || !ready || records.get(key) !== record) { result("rejected"); return }
      if (pending.response?.status !== 200 || !pending.data?.some(q => identity(q) === key && schema(q) === schema(record.original))) { result("rejected"); return }
      const outcome = await api.client.question.reply({ requestID: message.requestID, directory, answers })
      result(outcome.response?.status === 200 && outcome.data === true ? "accepted"
        : outcome.response?.status === 404 ? "rejected" : "unconfirmed")
    } catch { result("unconfirmed") }
  }
  unsubscribers.push(api.event.on("question.asked", ({ properties }) => {
    if (!ready || !validQuestion(properties)) return
    const key = identity(properties)
    if (records.has(key) || records.size >= 32) return
    const original = structuredClone(properties)
    if (Buffer.byteLength(JSON.stringify({ type: "asked", original }) + "\n") > LIMIT) return
    snapshotEvent(key, original)
    records.set(key, { original, deadline: performance.now() + 600000, attempted: false })
    send({ type: "asked", original })
  }))
  for (const type of ["question.replied", "question.rejected"]) {
    unsubscribers.push(api.event.on(type, ({ properties }) => {
      const key = properties.sessionID + "|" + properties.requestID
      snapshotEvent(key, null)
      records.delete(key)
      send({ type: "resolved", sessionID: properties.sessionID, requestID: properties.requestID })
    }))
  }
  try {
    watcher = watch(dirname(manifestPath), (_event, name) => {
      if (name && String(name) !== basename(manifestPath)) return
      clearTimeout(changed); changed = setTimeout(refresh, 50); changed.unref?.()
    })
    watcher.unref?.()
  } catch { /* No app-owned manifest: keep normal local questions available. */ }
  refresh()
  return { dispose() {
    if (disposed) return
    disposed = true; ready = false; connectionEpoch++; clearTimeout(retry); clearTimeout(changed)
    watcher?.close(); socket?.destroy(); records.clear(); for (const unsubscribe of unsubscribers) unsubscribe()
  } }
}

export default {
  id: "agrypnos-opencode",
  tui: async api => { const bridge = createOpenCodeBridge(api); api.lifecycle.onDispose(() => bridge.dispose()) },
}
