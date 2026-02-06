import http.server
import socketserver
import json
import os
import subprocess
import sys
import time
import threading

PORT = 8000
DATA_DIR = 'data'

def monitor_changes(filename):
    """Reinicia o servidor se o arquivo for modificado."""
    last_mtime = os.stat(filename).st_mtime
    while True:
        time.sleep(1)
        try:
            current_mtime = os.stat(filename).st_mtime
            if current_mtime != last_mtime:
                print("\n[AutoReload] Alteração detectada. Reiniciando servidor...")
                # Reinicia o processo atual
                os.execv(sys.executable, [sys.executable] + sys.argv)
        except OSError:
            pass

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/run-update':
            try:
                # Caminho absoluto para o script
                script_path = os.path.join(os.getcwd(), 'apps_update.ps1')
                
                # Executa o PowerShell
                # -ExecutionPolicy Bypass para evitar bloqueios
                # -NonInteractive para não travar
                result = subprocess.run(
                    ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path],
                    capture_output=True,
                    text=True
                )

                if result.returncode == 0:
                    response = {'status': 'success', 'output': result.stdout}
                    code = 200
                else:
                    response = {'status': 'error', 'output': result.stderr or result.stdout}
                    code = 500

                self.send_response(code)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode('utf-8'))

            except Exception as e:
                self.send_json_error(500, str(e))

        elif self.path == '/save':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))
                
                filename = data.get('filename')
                content = data.get('content')
                
                if not filename or content is None:
                    self.send_error(400, "Missing filename or content")
                    return
                
                # Security check: prevent directory traversal
                if os.path.basename(filename) != filename:
                    self.send_error(403, "Invalid filename")
                    return
                    
                # Only allow saving specific files for safety
                allowed_files = ['apps_output.csv', 'apps.csv', 'appSources.json']
                if filename not in allowed_files:
                     self.send_json_error(403, "File not allowed")
                     return

                # Ensure data directory exists
                if not os.path.exists(DATA_DIR):
                    os.makedirs(DATA_DIR)

                filepath = os.path.join(DATA_DIR, filename)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                    
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'status': 'success'}).encode('utf-8'))
                
            except Exception as e:
                self.send_json_error(500, str(e))
        else:
            self.send_json_error(404, "Endpoint not found")

    def send_json_error(self, code, message):
        self.send_response(code)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'error': message}).encode('utf-8'))

if __name__ == "__main__":
    # Inicia monitor de alterações em thread separada
    watcher = threading.Thread(target=monitor_changes, args=(__file__,))
    watcher.daemon = True
    watcher.start()

    print(f"Serving on port {PORT}")
    
    # Permite reuso da porta para evitar erro ao reiniciar rápido
    socketserver.TCPServer.allow_reuse_address = True
    
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
