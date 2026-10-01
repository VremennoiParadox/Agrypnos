"""Run real OpenCode/TUI/question tooling against a deterministic local model.

No provider credentials, OpenCode listener, bots, or existing chats are used.
The local HTTP fixture emulates only model responses, not OpenCode's API.
"""
import fcntl
import http.server
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import threading
import time
import uuid

mode = sys.argv[1] if len(sys.argv) > 1 else "ordinary"
probe = Path(__file__).with_name("opencode-tui-product.js" if mode == "bridge" else "opencode-tui-question.js").resolve()
fixture = Path(tempfile.mkdtemp(prefix="agrypnos-tui-probe-", dir="/private/tmp"))
marker = "AGRYPNOS_NATIVE_B_" + uuid.uuid4().hex
requests = []


class Model(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        messages = body.get("messages", [])
        answered = any(m.get("role") == "tool" for m in messages)
        requests.append({"toolAvailable": any(t.get("function", {}).get("name") == "question" for t in body.get("tools", [])), "answered": answered})
        args = {"questions": [{"question": "Choose A or B", "header": "Native probe", "options": [
            {"label": "A", "description": "First"}, {"label": "B", "description": "Second"}], "custom": False}]}
        delta = {"content": marker} if answered else {"tool_calls": [{"index": 0, "id": "call_native_probe", "type": "function", "function": {"name": "question", "arguments": json.dumps(args)}}]}
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for change, finish in [(delta, None), ({}, "stop" if answered else "tool_calls")]:
            item = {"id": "fixture", "object": "chat.completion.chunk", "created": 1,
                    "model": "native-probe", "choices": [{"index": 0, "delta": change, "finish_reason": finish}]}
            self.wfile.write(("data: " + json.dumps(item) + "\n\n").encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Model)
threading.Thread(target=server.serve_forever, daemon=True).start()
for child in ["config/opencode", "data", "cache", "state", "project"]:
    (fixture / child).mkdir(parents=True, exist_ok=True)
config = {"share": "disabled", "model": "fixture/native-probe", "provider": {"fixture": {
    "npm": "@ai-sdk/openai-compatible", "name": "Native probe", "options": {
        "baseURL": f"http://127.0.0.1:{server.server_port}/v1", "apiKey": "fixture-only"},
    "models": {"native-probe": {"name": "Native probe", "limit": {"context": 32000, "output": 2000}}}}}}
(fixture / "config/opencode/opencode.json").write_text(json.dumps(config))
(fixture / "config/opencode/tui.json").write_text(json.dumps({"plugin": [probe.as_uri()]}))
env = {"PATH": "/opt/homebrew/bin:/usr/bin:/bin", "TERM": "xterm-256color",
       "OPENCODE_DISABLE_AUTOUPDATE": "1", "OPENCODE_DISABLE_DEFAULT_PLUGINS": "1",
       "OPENCODE_DISABLE_MODELS_FETCH": "1", "AGRYPNOS_PROBE_OUTPUT": str(fixture / "runtime.json"),
       "AGRYPNOS_PROBE_MODE": mode, "AGRYPNOS_PROBE_MARKER": marker}
if mode == "bridge":
    module = fixture / "agrypnos-opencode.mjs"
    module.write_bytes((Path(__file__).resolve().parents[2] / "Apps/Agrypnos/Resources/agrypnos-opencode.js").read_bytes())
    env["AGRYPNOS_PRODUCT_MODULE"] = module.as_uri()
    env["AGRYPNOS_PRODUCT_MANIFEST"] = sys.argv[2]
for name in ["CONFIG", "DATA", "CACHE", "STATE"]:
    env[f"XDG_{name}_HOME"] = str(fixture / name.lower())
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 36, 120, 0, 0))
process = subprocess.Popen(["/opt/homebrew/bin/opencode", str(fixture / "project"),
                            "--prompt", "Perform the harmless native A/B probe."],
                           env=env, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
os.close(slave)
deadline = time.monotonic() + 60
report = {}
try:
    with (fixture / "terminal.log").open("wb") as log:
        while process.poll() is None and time.monotonic() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    break
                log.write(data)
                if b"\x1b]10;?" in data:
                    os.write(master, b"\x1b]10;rgb:ffff/ffff/ffff\x07\x1b]11;rgb:0000/0000/0000\x07\x1b[?1;2c\x1b[8;36;120t")
            path = fixture / "runtime.json"
            if path.exists():
                try:
                    report = json.loads(path.read_text())
                except json.JSONDecodeError:
                    continue
                if report.get("markerCount") == 1 or report.get("localPromptAvailable"):
                    break
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=6)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
    os.close(master)
    server.shutdown()
if (fixture / "runtime.json").exists():
    report = json.loads((fixture / "runtime.json").read_text())
print("Fixture:", fixture)
print(json.dumps(report, indent=2))
print("Model requests:", json.dumps(requests))
ok = report.get("hostVersion") == "1.18.32" and report.get("questionReply") and report.get("pendingListed")
ok = ok and (report.get("localPromptAvailable") if mode == "unavailable" else (mode == "bridge" or report.get("accepted")) and report.get("markerCount") == 1 and report.get("continuedSessionID") == report.get("originalSessionID"))
sys.exit(0 if ok else 1)
