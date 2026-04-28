from flask import Flask, request, jsonify, send_from_directory
import subprocess
import os
import json
import time
import threading

app = Flask(__name__, static_folder='assets', static_url_path='/assets')

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

        elif self.path == '/update-single-app':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                print(f"DEBUG: Received data: {post_data}")
                
                try:
                    data = json.loads(post_data.decode('utf-8'))
                    print(f"DEBUG: Parsed JSON: {data}")
                except json.JSONDecodeError as e:
                    print(f"DEBUG: JSON decode error: {e}")
                    self.send_json_error(400, f"Invalid JSON: {e}")
                    return
                
                app_name = data.get('appName')
                print(f"DEBUG: App name: {app_name}")
                
                if not app_name:
                    self.send_json_error(400, "Missing appName")
                    return
                
                # Caminho absoluto para o novo script simplificado
                script_path = os.path.join(os.getcwd(), 'check_single_app.ps1')
                print(f"DEBUG: Script path: {script_path}")
                
                # Executa o PowerShell para check individual
                result = subprocess.run(
                    ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path, 
                     "-SingleAppName", f'"{app_name}"', "-Quiet"],
                    capture_output=True,
                    text=True
                )
                
                print(f"DEBUG: PowerShell return code: {result.returncode}")
                print(f"DEBUG: PowerShell stdout: {result.stdout}")
                print(f"DEBUG: PowerShell stderr: {result.stderr}")

                # Parse do resultado JSON
                try:
                    if result.returncode == 0:
                        # Extrair apenas o JSON do output (última linha que começa com {)
                        output_lines = result.stdout.strip().split('\n')
                        json_line = None
                        for line in reversed(output_lines):
                            line = line.strip()
                            if line.startswith('{') and line.endswith('}'):
                                json_line = line
                                break
                            elif line.startswith('{'):
                                # Procurar pelo JSON completo que pode ter múltiplas linhas
                                json_start = output_lines.index(line)
                                json_lines = [line]
                                for i in range(json_start + 1, len(output_lines)):
                                    json_lines.append(output_lines[i])
                                    if output_lines[i].strip().endswith('}'):
                                        break
                                json_line = '\n'.join(json_lines)
                                break
                        
                        if json_line:
                            result_data = json.loads(json_line)
                            response = {'success': True, 'app': result_data.get('app', {})}
                            code = 200
                        else:
                            response = {'success': False, 'error': 'No JSON found in output'}
                            code = 500
                    else:
                        # Tenta fazer parse do erro
                        try:
                            error_data = json.loads(result.stdout)
                            response = {'success': False, 'error': error_data.get('error', result.stderr)}
                        except:
                            response = {'success': False, 'error': result.stderr or result.stdout}
                        code = 500
                except json.JSONDecodeError as e:
                    print(f"DEBUG: JSON parse error: {e}")
                    response = {'success': False, 'error': f'JSON parse error: {result.stderr or result.stdout}'}
                    code = 500

                print(f"DEBUG: Final response: {response}")
                self.send_response(code)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode('utf-8'))

            except Exception as e:
                print(f"DEBUG: Exception in handler: {e}")
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
            self.send_json_error(404, "Endpoint not found. Available: /run-update, /update-single-app, /save")

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
