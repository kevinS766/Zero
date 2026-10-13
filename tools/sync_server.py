import http.server
import json
import os
import sys

PORT = 34567
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC_DIR = os.path.join(BASE_DIR, "src")

SERVICE_MAP = {
    "ServerScriptService": os.path.join(SRC_DIR, "server"),
    "ReplicatedStorage": os.path.join(SRC_DIR, "shared"),
    "StarterPlayer": os.path.join(SRC_DIR, "client"),
    "StarterPlayerScripts": os.path.join(SRC_DIR, "client"),
    "StarterGui": os.path.join(SRC_DIR, "startergui"),
    "ReplicatedFirst": os.path.join(SRC_DIR, "replicatedfirst"),
    "ServerStorage": os.path.join(SRC_DIR, "serverstorage"),
}

class SyncHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"ready"}')

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        try:
            data = json.loads(post_data.decode("utf-8"))
            scripts = data.get("scripts", [])
            saved = 0
            for item in scripts:
                service = item.get("service")
                rel_path = item.get("path")
                cls = item.get("class", "ModuleScript")
                source = item.get("source", "")

                base = SERVICE_MAP.get(service, os.path.join(SRC_DIR, service.lower()))
                
                # Determine extension
                if cls == "Script":
                    ext = ".server.luau"
                elif cls == "LocalScript":
                    ext = ".client.luau"
                else:
                    ext = ".luau"

                full_path = os.path.join(base, rel_path + ext)
                os.makedirs(os.path.dirname(full_path), exist_ok=True)
                with open(full_path, "w", encoding="utf-8") as f:
                    f.write(source)
                saved += 1

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            resp = json.dumps({"status": "ok", "saved": saved})
            self.wfile.write(resp.encode("utf-8"))
            print(f"Successfully saved {saved} scripts from {service}")
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            err_resp = json.dumps({"error": str(e)})
            self.wfile.write(err_resp.encode("utf-8"))
            print(f"Error handling sync request: {e}")

    def log_message(self, format, *args):
        # Quiet default logging
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format%args))

def run():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), SyncHandler)
    print(f"Sync server listening on http://127.0.0.1:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    run()
