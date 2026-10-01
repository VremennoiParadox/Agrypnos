import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile, writeFile, mkdtemp, chmod, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { createServer } from 'node:net'
import { randomUUID } from 'node:crypto'
import { once } from 'node:events'
import { setTimeout as delay } from 'node:timers/promises'

const source = await readFile(new URL('../../Apps/Agrypnos/Resources/agrypnos-opencode.js', import.meta.url))
const { createOpenCodeBridge, RETRY_SECONDS } = await import('data:text/javascript;base64,' + source.toString('base64'))
const question = { id: 'que_abc', sessionID: 'session', questions: [{ question: 'Choose', options: [{ label: 'A' }, { label: 'B' }], custom: false }] }

async function fixture(t, delivery = true) {
  const root = await mkdtemp('/private/tmp/ag-js-')
  await chmod(root, 0o700)
  const generation = randomUUID(), token = 'a'.repeat(64), socketPath = root + '/s.sock'
  const frames = [], handlers = new Map()
  let peer, count = 0, pending = [question], resolveReply
  const server = createServer(socket => {
    peer = socket
    let buffer = ''
    socket.on('data', bytes => {
      buffer += bytes
      while (buffer.includes('\n')) {
        const end = buffer.indexOf('\n'), message = JSON.parse(buffer.slice(0, end)); buffer = buffer.slice(end + 1)
        frames.push(message)
        if (message.type === 'hello') socket.write(JSON.stringify({ type: 'ready', generation }) + '\n')
      }
    })
  })
  server.listen(socketPath); await once(server, 'listening'); await chmod(socketPath, 0o600)
  const manifestPath = root + '/bridge.json'
  await writeFile(manifestPath, JSON.stringify({ active: true, protocolVersion: 1, socketPath, token, generation }), { mode: 0o600 })
  const api = { app: { version: '1.18.32' }, state: { path: { directory: '/project' } },
    event: { on(type, handler) { handlers.set(type, handler); return () => handlers.delete(type) } },
    lifecycle: { onDispose() {} }, client: { question: {
      async list() { return { data: pending, response: { status: 200 } } },
      async reply(input) { count++; assert.deepEqual(input.answers, [['B']]);
        handlers.get('question.replied')?.({ properties: { requestID: question.id, sessionID: question.sessionID } })
        pending = []
        if (delivery === 'hold') await new Promise(r => resolveReply = r)
        return { data: delivery === true || delivery === 'hold', response: { status: delivery === false ? 404 : 200 } }
      }
    } } }
  const bridge = createOpenCodeBridge(api, { manifestPath })
  const waitFor = async predicate => { for (let i = 0; i < 100; i++) { if (predicate()) return; await delay(10) } assert.fail('timed out') }
  await waitFor(() => frames.some(f => f.type === 'snapshot'))
  t.after(async () => { bridge.dispose(); peer?.destroy(); await new Promise(r => server.close(r)); await rm(root, { recursive: true, force: true }) })
  const ask = () => handlers.get('question.asked')({ properties: structuredClone(question) })
  const reply = () => peer.write(JSON.stringify({ type: 'reply', attemptID: randomUUID(), sessionID: 'session', requestID: 'que_abc', answers: [['B']] }) + '\n')
  return { frames, api, handlers, ask, reply, waitFor, bridge, manifestPath, generation, token, socketPath, count: () => count, resolve: () => resolveReply?.(), peer: () => peer }
}

test('native result alone accepts; duplicate replies never call twice', async t => {
  const f = await fixture(t); f.ask(); await f.waitFor(() => f.frames.some(m => m.type === 'asked'))
  f.reply(); await f.waitFor(() => f.frames.some(m => m.type === 'result'))
  assert.equal(f.frames.find(m => m.type === 'result').delivery, 'accepted')
  f.reply(); await delay(30); assert.equal(f.count(), 1)
})
test('resolved event cannot accept before native acknowledgment', async t => {
  const f = await fixture(t, 'hold'); f.ask(); f.reply()
  await f.waitFor(() => f.frames.some(m => m.type === 'resolved'))
  assert.equal(f.frames.some(m => m.type === 'result'), false)
  f.resolve(); await f.waitFor(() => f.frames.some(m => m.type === 'result'))
  assert.equal(f.count(), 1)
})
test('local winner makes a remote reply harmless', async t => {
  const f = await fixture(t); f.ask()
  f.handlers.get('question.replied')({ properties: { requestID: 'que_abc', sessionID: 'session' } })
  f.reply(); await f.waitFor(() => f.frames.some(m => m.type === 'result'))
  assert.equal(f.count(), 0); assert.equal(f.frames.find(m => m.type === 'result').delivery, 'rejected')
})
test('native 404 is rejected', async t => {
  const f = await fixture(t, false); f.ask(); f.reply()
  await f.waitFor(() => f.frames.some(m => m.type === 'result'))
  assert.equal(f.frames.find(m => m.type === 'result').delivery, 'rejected'); assert.equal(f.count(), 1)
})
test('retry schedule is capped and has no question polling timer', () => {
  assert.deepEqual(RETRY_SECONDS, [1, 2, 4, 8, 16, 30])
  assert.equal(source.toString().includes('setInterval'), false)
})

test('disable leaves new questions local and disposal removes subscriptions', async t => {
  const f = await fixture(t)
  await writeFile(f.manifestPath, JSON.stringify({ active: false, protocolVersion: 1 }), { mode: 0o600 })
  await f.waitFor(() => f.peer().destroyed)
  f.ask(); await delay(30)
  assert.equal(f.frames.some(m => m.type === 'asked'), false)
  assert.equal(f.count(), 0)
  f.bridge.dispose(); assert.equal(f.handlers.size, 0)
})
test('return local never submits a native answer', async t => {
  const f = await fixture(t); f.ask()
  f.peer().write(JSON.stringify({ type: 'local', sessionID: 'session', requestID: 'que_abc' }) + '\n')
  f.reply(); await f.waitFor(() => f.frames.some(m => m.type === 'result'))
  assert.equal(f.frames.find(m => m.type === 'result').delivery, 'rejected')
  assert.equal(f.count(), 0)
})
test('oversized input closes rather than buffering unbounded bytes', async t => {
  const f = await fixture(t)
  f.peer().write(Buffer.alloc(262144, 65))
  await f.waitFor(() => f.peer().destroyed)
  assert.equal(f.count(), 0)
})

test('wrong native identity and undeclared labels never reach the API', async t => {
  const f = await fixture(t); f.ask()
  for (const input of [
    { sessionID: 'another', requestID: 'que_abc', answers: [['B']] },
    { sessionID: 'session', requestID: 'que_abc', answers: [['invented']] },
  ]) f.peer().write(JSON.stringify({ type: 'reply', attemptID: randomUUID(), ...input }) + '\n')
  await f.waitFor(() => f.frames.filter(m => m.type === 'result').length === 2)
  assert.equal(f.count(), 0)
  assert.ok(f.frames.filter(m => m.type === 'result').every(m => m.delivery === 'rejected'))
})
