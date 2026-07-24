#!/usr/bin/env python3
"""抖音素材收集 - 本地接收服务"""
import json, os, sys, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
PENDING_FILE = os.path.join(DATA_DIR, "pending.json")
DONE_FILE = os.path.join(DATA_DIR, "done.json")
LOG_FILE = os.path.join(DATA_DIR, "server.log")

os.makedirs(DATA_DIR, exist_ok=True)

def log(msg):
    timestamp = time.strftime("%H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line, flush=True)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()

        if path == "/pending":
            data = self._load(PENDING_FILE)
        elif path == "/done":
            data = self._load(DONE_FILE)
        elif path == "/status":
            pending = self._load(PENDING_FILE)
            done = self._load(DONE_FILE)
            data = {"pending": len(pending), "done": len(done), "pending_items": pending}
        else:
            data = {"error": "unknown path"}

        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        path = urlparse(self.path).path

        try:
            items = json.loads(body)
        except:
            self._reply(400, {"error": "invalid json"})
            return

        if path == "/submit":
            existing = self._load(PENDING_FILE)
            # 去重
            old_urls = {i["url"] for i in existing}
            new_items = [i for i in items if i.get("url") and i["url"] not in old_urls]
            existing.extend(new_items)
            self._save(PENDING_FILE, existing)
            log(f"收到 {len(new_items)} 条新内容 (共 {len(existing)} 条待处理)")
            self._reply(200, {"ok": True, "new": len(new_items), "total": len(existing)})

        elif path == "/mark-done":
            urls = set(items.get("urls", []))
            pending = self._load(PENDING_FILE)
            done = self._load(DONE_FILE)
            today = time.strftime("%Y-%m-%d")

            new_done = [p for p in pending if p["url"] in urls]
            for item in new_done:
                item["processed_at"] = today
            remaining = [p for p in pending if p["url"] not in urls]
            done.extend(new_done)

            self._save(PENDING_FILE, remaining)
            self._save(DONE_FILE, done)
            log(f"标记完成 {len(new_done)} 条")
            self._reply(200, {"ok": True, "done": len(new_done), "remaining": len(remaining)})

        else:
            self._reply(404, {"error": "unknown path"})

    def _reply(self, code, data):
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def _load(self, path):
        if os.path.exists(path):
            with open(path) as f:
                return json.load(f)
        return []

    def _save(self, path, data):
        with open(path, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def log_message(self, format, *args):
        pass  # 静默 HTTP 日志

def main():
    port = 8788
    log(f"服务启动: http://localhost:{port}")
    log(f"待处理数据: {PENDING_FILE}")
    server = HTTPServer(("127.0.0.1", port), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("服务已停止")
        server.shutdown()

if __name__ == "__main__":
    main()
