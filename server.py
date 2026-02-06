import http.server
import socketserver
import json
import os

PORT = 8000
DATA_DIR = 'data'

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/save':
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

print(f"Serving on port {PORT}")
with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    httpd.serve_forever()
