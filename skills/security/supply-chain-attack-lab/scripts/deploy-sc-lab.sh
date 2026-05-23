#!/bin/bash
# Supply Chain Lab — Systemd-based deployment
# Run on Proxmox host. Requires containers 310-313, 320 already provisioned.
# All services use Python 3 stdlib only — zero package installs needed.

set -e
echo "=== Supply Chain Lab Deployment ==="

# ---- 310: CI Runner ----
cat > /tmp/ci_runner.py << 'PYEOF'
import json, http.server, socketserver, sqlite3

DB = "/opt/ci_pipeline.db"
conn = sqlite3.connect(DB)
conn.execute("CREATE TABLE IF NOT EXISTS builds (id INTEGER PRIMARY KEY, project TEXT, status TEXT, build_secret TEXT, deployed_to TEXT)")
conn.execute("INSERT OR REPLACE INTO builds VALUES (1,'internal-api','success','DEPLOY_KEY_XyZ-987654','prod-us-east-1')")
conn.execute("INSERT OR REPLACE INTO builds VALUES (2,'auth-service','success','DEPLOY_KEY_AbC-123456','prod-eu-west-1')")
conn.execute("INSERT OR REPLACE INTO builds VALUES (3,'frontend','success','DEPLOY_KEY_PqR-456789','prod-us-west-2')")
conn.commit()
conn.close()

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        rows = list(sqlite3.connect(DB).execute("SELECT * FROM builds"))
        self.wfile.write(json.dumps([dict(zip(["id","project","status","secret","deployed"], r)) for r in rows]).encode())
    def do_POST(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(json.dumps({"status":"ok","webhook":"triggered"}).encode())
    def log_message(self,*a): pass

socketserver.TCPServer(("0.0.0.0", 9000), Handler).serve_forever()
PYEOF

cat > /tmp/ci-runner.service << 'UNITEOF'
[Unit]
Description=CI Runner Webhook
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/ci_runner.py
Restart=always
[Install]
WantedBy=multi-user.target
UNITEOF

pct push 310 /tmp/ci_runner.py /opt/ci_runner.py
pct push 310 /tmp/ci-runner.service /etc/systemd/system/ci-runner.service
pct exec 310 -- systemctl daemon-reload
pct exec 310 -- systemctl enable --now ci-runner
echo "CT 310: CI runner on :9000"

# ---- 311: Dependency Proxy ----
cat > /tmp/dep_proxy.py << 'PYEOF'
import http.server, socketserver, json

packages = {"internal-lib":"1.0.0","company-auth":"2.3.1","data-utils":"0.5.0"}

class Proxy(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ["/simple","/simple/"]:
            html = "<html><body><h1>Internal PyPI</h1>"
            for pkg,ver in packages.items():
                html += f'<a href=/simple/{pkg}/>{pkg} ({ver})</a><br>'
            html += "</body></html>"
            self.send_response(200); self.send_header("Content-type","text/html"); self.end_headers()
            self.wfile.write(html.encode())
        elif self.path.startswith("/simple/"):
            pkg = self.path.split("/")[2].rstrip("/")
            if pkg in packages:
                self.send_response(200); self.send_header("Content-type","text/html"); self.end_headers()
                self.wfile.write(f"<a href=/packages/{pkg}-{packages[pkg]}.tar.gz>{pkg} ({packages[pkg]})</a>".encode())
            else:
                self.send_response(404); self.end_headers()
        else:
            self.send_response(200); self.end_headers()
            self.wfile.write(b"Internal Dependency Proxy - /simple/ for index")
    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0))
        if content_len > 0:
            body = json.loads(self.rfile.read(content_len))
            packages[body["name"]] = body.get("version", "unknown")
        self.send_response(200); self.end_headers()
        self.wfile.write(json.dumps({"ok":True}).encode())
    def log_message(self,*a): pass

socketserver.TCPServer(("0.0.0.0", 8888), Proxy).serve_forever()
PYEOF

cat > /tmp/dep-proxy.service << 'UNITEOF'
[Unit]
Description=Dependency Proxy
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/dep_proxy.py
Restart=always
[Install]
WantedBy=multi-user.target
UNITEOF

pct push 311 /tmp/dep_proxy.py /opt/dep_proxy.py
pct push 311 /tmp/dep-proxy.service /etc/systemd/system/dep-proxy.service
pct exec 311 -- systemctl daemon-reload
pct exec 311 -- systemctl enable --now dep-proxy
echo "CT 311: Dep proxy on :8888"

# ---- 312: Artifact Registry ----
cat > /tmp/registry.py << 'PYEOF'
import http.server, socketserver, json

images = {"internal-api":["v1.0.0","v1.2.3"],"auth-service":["v2.0.0","v2.1.0"],"frontend":["v4.0.1"]}

class Reg(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.send_header("Content-type","application/json"); self.end_headers()
        if self.path == "/v2/_catalog":
            self.wfile.write(json.dumps({"repositories":list(images.keys())}).encode())
        elif "/tags/list" in self.path:
            for img in images:
                if img in self.path:
                    self.wfile.write(json.dumps({"name":img,"tags":images[img]}).encode())
                    return
            self.wfile.write(b"{}")
        else:
            self.wfile.write(json.dumps({"status":"Registry v2"}).encode())
    def do_PUT(self):
        self.send_response(201); self.end_headers()
        self.wfile.write(b'{"status":"accepted"}')
    def log_message(self,*a): pass

socketserver.TCPServer(("0.0.0.0", 5000), Reg).serve_forever()
PYEOF

cat > /tmp/registry.service << 'UNITEOF'
[Unit]
Description=Artifact Registry
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/registry.py
Restart=always
[Install]
WantedBy=multi-user.target
UNITEOF

pct push 312 /tmp/registry.py /opt/registry.py
pct push 312 /tmp/registry.service /etc/systemd/system/registry.service
pct exec 312 -- systemctl daemon-reload
pct exec 312 -- systemctl enable --now registry
echo "CT 312: Registry on :5000"

# ---- 313: Developer Workstation (files only) ----
pct exec 313 -- python3 -c "
import os
os.makedirs('/home/dev/projects/internal-api', exist_ok=True)
with open('/home/dev/projects/internal-api/.env','w') as f:
    f.write('AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF\nAWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\nGITLAB_TOKEN=glpat-abcdef1234567890\nCI_REGISTRY_PASSWORD=r3g1stry-p@ssw0rd!\nDATABASE_URL=mysql://admin:SuperSecretDB2026!@10.66.0.10:3306/ci_pipeline\n')
with open('/home/dev/projects/internal-api/api.py','w') as f:
    f.write('DB_USER = \"admin\"\nDB_PASS = \"SuperSecretDB2026!\"\nDB_HOST = \"10.66.0.10\"\nDEPLOY_KEY = \"DEPLOY_KEY_XyZ-987654\"\nAWS_KEY = \"AKIA1234567890ABCDEF\"\n')
"
echo "CT 313: Dev workstation with secrets"

# ---- Verify ----
sleep 2
echo ""
echo "=== Verification ==="
for ct in 310 311 312; do
  echo -n "CT $ct: "
  pct exec $ct -- ss -tlnp 2>/dev/null | grep -vE "127|::1|sshd|systemd" | grep -oP ":\d+" | head -1 || echo "OFFLINE"
done
echo "CT 313: $(pct exec 313 -- test -f /home/dev/projects/internal-api/.env && echo 'secrets ready' || echo 'MISSING')"
echo "=== Lab Ready ==="
