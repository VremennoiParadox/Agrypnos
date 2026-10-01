// Disposable feasibility probe. Never bundle or install in the user's config.
import assert from "node:assert/strict"
import { readFileSync, realpathSync, writeFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import { createConnection } from "node:net"
import { pathToFileURL } from "node:url"

export async function AgrypnosOpenCodeProbe(input) {
  const output = process.env.AGRYPNOS_PROBE_OUTPUT
  if (!output) return {}
  const report = {
    loaded: true,
    hostVersion: execFileSync(process.execPath, ["--version"], {
      encoding: "utf8", timeout: 5000,
    }).trim(),
    questionReply: typeof input.client.question?.reply === "function",
    questionList: typeof input.client.question?.list === "function",
    globalHealth: typeof input.client.global?.health === "function",
    publicRequest: typeof input.client.request === "function",
    nodeNetAvailable: typeof createConnection === "function",
    directoryMatches: false,
    disposed: false,
    questionAskedObserved: false,
    cases: {},
  }
  // Exercise the supplied public transport without reading config or credentials.
  const path = await input.client.path.get({ signal: AbortSignal.timeout(2000) })
  if (typeof path.data?.directory === "string")
    report.directoryMatches = realpathSync(path.data.directory) === realpathSync(input.directory)
  const save = () => writeFileSync(output, JSON.stringify(report, null, 2), { mode: 0o600 })
  save()
  return {
    event: async ({ event }) => {
      if (event.type !== "question.asked") return
      report.questionAskedObserved = true
      save()
    },
    dispose: async () => {
      report.disposed = true
      save()
    },
  }
}

function verify(report) {
  const cases = {
    ordinaryStartupOriginalReply(result) {
      assert.equal(result.continuedSessionID, result.originalSessionID)
      assert.equal(result.markerCount, 1)
      assert.equal(result.replyAttempts, 1)
    },
    localAnswerWins(result) {
      assert.equal(result.localResolutionObserved, true)
      assert.equal(result.replyAttempts, 0)
      assert.equal(result.markerCount, 1)
    },
    resolvedBeforeAcknowledgment(result) {
      assert.equal(result.resolutionBeforeAcknowledgmentObserved, true)
      assert.equal(result.acceptedBeforeAcknowledgment, false)
      assert.equal(result.replyAttempts, 1)
      assert.equal(result.markerCount, 1)
    },
    twoProjectsAndProcesses(result) {
      assert.equal(result.owners.length, 2)
      assert.notEqual(result.owners[0].instanceID, result.owners[1].instanceID)
      assert.notEqual(result.owners[0].directory, result.owners[1].directory)
      for (const owner of result.owners) {
        assert.equal(owner.continuedSessionID, owner.originalSessionID)
        assert.equal(owner.markerCount, 1)
        assert.equal(owner.replyAttempts, 1)
      }
    },
    appUnavailableLeavesLocal(result) {
      assert.equal(result.ipcUnavailableObserved, true)
      assert.equal(result.localPromptAvailable, true)
      assert.equal(result.replyAttempts, 0)
    },
    publicContractOnly(result) {
      assert.equal(result.publicReplyVerified, true)
      assert.equal(result.publicPendingListVerified, true)
      assert.equal(result.privateAccessUsed, false)
    },
  }
  let failed = 0
  for (const [name, check] of Object.entries(cases)) {
    try {
      const result = report.cases?.[name]
      assert.ok(result?.observed, "native case not observed")
      assert.equal(result.hostVersion, "1.18.32")
      assert.equal(result.requiresExplicitListener, false)
      if (name !== "publicContractOnly") {
        for (const key of ["instanceID", "originalSessionID", "originalRequestID"])
          assert.ok(typeof result[key] === "string" && result[key].length > 0, key)
      }
      check(result)
      console.log(`${name}: PASS`)
    } catch (error) {
      failed++
      console.log(`${name}: FAIL — ${error.message.split("\n")[0]}`)
    }
  }
  return failed ? 1 : 0
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv[2] !== "--verify" || !process.argv[3]) {
    console.error("Usage: node scripts/probes/opencode-plugin-question.js --verify REPORT.json")
    process.exitCode = 2
  } else {
    process.exitCode = verify(JSON.parse(readFileSync(process.argv[3], "utf8")))
  }
}
