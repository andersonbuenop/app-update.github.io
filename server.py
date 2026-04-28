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

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('.', path)

@app.route('/run-update', methods=['POST'])
def run_update():
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

        return jsonify(response), code

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/update-single-app', methods=['POST'])
def update_single_app():
    try:
        data = request.get_json()
        app_name = data.get('appName')
        
        if not app_name:
            return jsonify({'error': 'Missing appName'}), 400
        
        # Caminho absoluto para o novo script simplificado
        script_path = os.path.join(os.getcwd(), 'check_single_app.ps1')
        
        # Executa o PowerShell para check individual
        result = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", script_path, 
             "-SingleAppName", f'"{app_name}"', "-Quiet"],
            capture_output=True,
            text=True
        )
        
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
            response = {'success': False, 'error': f'JSON parse error: {result.stderr or result.stdout}'}
            code = 500

        return jsonify(response), code

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/save', methods=['POST'])
def save():
    try:
        data = request.get_json()
        
        filename = data.get('filename')
        content = data.get('content')
        
        if not filename or content is None:
            return jsonify({'error': 'Missing filename or content'}), 400
        
        # Security check: prevent directory traversal
        if os.path.basename(filename) != filename:
            return jsonify({'error': 'Invalid filename'}), 403
        
        # Only allow saving specific files for safety
        allowed_files = ['apps_output.csv', 'apps.csv', 'appSources.json']
        if filename not in allowed_files:
            return jsonify({'error': 'File not allowed'}), 403

        # Ensure data directory exists
        if not os.path.exists(DATA_DIR):
            os.makedirs(DATA_DIR)

        filepath = os.path.join(DATA_DIR, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
        return jsonify({'status': 'success'}), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    # Inicia monitor de alterações em thread separada
    watcher = threading.Thread(target=monitor_changes, args=(__file__,))
    watcher.daemon = True
    watcher.start()
    
    print(f"Serving on port {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=True)