import json
import logging
from http.server import BaseHTTPRequestHandler, HTTPServer


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


class AlertHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            self.send_error(404)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok\n")

    def do_POST(self):
        if self.path != "/alerts":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length))
        except (ValueError, json.JSONDecodeError):
            self.send_error(400, "Expected a JSON alert payload")
            return

        logging.info("Received Grafana alert webhook: %s", json.dumps(payload))
        self.send_response(202)
        self.end_headers()
        self.wfile.write(b"accepted\n")

    def log_message(self, format, *args):
        logging.info("%s - %s", self.address_string(), format % args)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), AlertHandler).serve_forever()
