import http.server
import socketserver
import urllib.parse
import webbrowser
import requests
import base64
import os
import subprocess

CLIENT_ID = "1842aff694404946af4ac03a457c54ab"
CLIENT_SECRET = "b90742dc54544188a5e2f88d5383bd3c"
REDIRECT_URI = "http://127.0.0.1:8888/callback"
PORT = 8888

AUTH_URL = (
    f"https://accounts.spotify.com/authorize"
    f"?client_id={CLIENT_ID}"
    f"&response_type=code"
    f"&redirect_uri={urllib.parse.quote(REDIRECT_URI)}"
    f"&scope=user-read-currently-playing%20user-read-playback-state%20user-modify-playback-state"
)

auth_code = None

class OAuthHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if "code" in params:
            auth_code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
            <html>
            <head><title>Spotify Connected</title></head>
            <body style="font-family:Arial,sans-serif;text-align:center;padding-top:60px;background:#121212;color:#fff;">
                <h1 style="color:#1DB954;">&#10004; Spotify Connected Successfully!</h1>
                <p>You can close this window now and check your terminal.</p>
            </body>
            </html>
            """)
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"No code found in URL query parameters.")

    def log_message(self, format, *args):
        pass

def exchange_code(code):
    token_url = "https://accounts.spotify.com/api/token"
    auth_header = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    headers = {
        "Authorization": f"Basic {auth_header}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    payload = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI
    }

    resp = requests.post(token_url, headers=headers, data=payload)
    if resp.status_code == 200:
        data = resp.json()
        refresh_token = data.get("refresh_token")
        access_token = data.get("access_token")
        return refresh_token, access_token
    else:
        print("[!] Error during token exchange:", resp.text)
        return None, None

def copy_to_clipboard(text):
    try:
        process = subprocess.Popen(['clip'], stdin=subprocess.PIPE, close_fds=True)
        process.communicate(input=text.encode('utf-8'))
        return True
    except Exception:
        return False

def main():
    print("=" * 60)
    print("       FIH UI - SPOTIFY PERMANENT REFRESH TOKEN GENERATOR")
    print("=" * 60)
    print(f"[*] Starting local callback server on http://127.0.0.1:{PORT}...")

    with socketserver.TCPServer(("127.0.0.1", PORT), OAuthHandler) as httpd:
        print(f"[*] Opening browser for Spotify authorization...")
        webbrowser.open(AUTH_URL)
        print("[*] Waiting for authorization approval...")

        while auth_code is None:
            httpd.handle_request()

    print("\n[+] Authorization code captured successfully!")
    print("[*] Exchanging code for permanent Refresh Token...")
    
    refresh_token, access_token = exchange_code(auth_code)

    if refresh_token:
        print("\n" + "=" * 60)
        print("          PERMANENT REFRESH TOKEN (NEVER EXPIRES)")
        print("=" * 60)
        print(f"\n{refresh_token}\n")
        print("=" * 60)

        if copy_to_clipboard(refresh_token):
            print("[+] Token has been AUTOMATICALLY copied to your clipboard!")
        
        print("[*] Paste this into the 'Permanent Refresh Token' box in the Fih UI Music tab.")
    else:
        print("[-] Failed to retrieve refresh token.")

if __name__ == "__main__":
    main()
