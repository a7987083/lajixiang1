#!/usr/bin/env python3
"""Bounded read-only IPA upload scanner. Bind loopback; put behind authenticated proxy."""
import json
import os
import secrets
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from scan import scan

MAX_UPLOAD = 128 * 1024 * 1024
TOKEN = os.environ.get("IPA_SCAN_TOKEN", "")
class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def reply(self, code, data):
        b=json.dumps(data,ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Cache-Control","no-store")
        self.send_header("X-Content-Type-Options","nosniff")
        self.send_header("Content-Length",str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def do_POST(self):
        if urlsplit(self.path).path != "/ipa-tools/scan":
            return self.reply(404,{"error":"not_found"})
        if not TOKEN or not secrets.compare_digest(self.headers.get("X-IPA-Scan-Token",""),TOKEN):
            self.close_connection=True
            return self.reply(403,{"error":"forbidden"})
        length=self.headers.get("Content-Length","")
        if not length.isdigit() or not 28 <= int(length) <= MAX_UPLOAD:
            self.close_connection=True
            return self.reply(413,{"error":"size_limit"})
        if self.headers.get("Content-Type","").split(";")[0] != "application/octet-stream":
            self.close_connection=True
            return self.reply(415,{"error":"expected_octet_stream"})
        remaining=int(length)
        with tempfile.TemporaryDirectory(prefix="ipa-scan-") as d:
            path=Path(d)/"uploaded.ipa"
            with path.open("wb") as f:
                while remaining:
                    chunk=self.rfile.read(min(65536,remaining))
                    if not chunk:break
                    f.write(chunk)
                    remaining-=len(chunk)
            if remaining:
                self.close_connection=True
                return self.reply(400,{"error":"incomplete_upload"})
            try:
                result=scan(path)
                result.pop("ipa",None)
                return self.reply(200,result)
            except (ValueError, OSError, EOFError) as e:
                return self.reply(400,{"error":str(e)[:180]})
    def do_GET(self):
        return self.reply(404,{"error":"not_found"})
    def log_message(self,fmt,*args):
        pass
if __name__=="__main__":
    if len(TOKEN)<32:raise SystemExit("Set IPA_SCAN_TOKEN to a 32+ character random string")
    ThreadingHTTPServer(("127.0.0.1",18767),Handler).serve_forever()
