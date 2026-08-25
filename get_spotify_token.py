import base64
import http.server
import json
import os
import socket
import threading
import tkinter as tk
from tkinter import ttk, messagebox
import urllib.parse
import urllib.request
import webbrowser

REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = (
    "user-read-currently-playing "
    "user-read-playback-state "
    "user-modify-playback-state "
    "user-read-recently-played"
)

BG       = "#0d0d0d"
CARD     = "#161616"
BORDER   = "#2a2a2a"
GREEN    = "#1DB954"
GREEN_HV = "#1ed760"
TEXT     = "#f0f0f0"
SUBTEXT  = "#a0a0a0"
RED      = "#e05050"
FONT_UI  = ("Segoe UI", 10)
FONT_MONO= ("Consolas", 9)

def find_free_port(start=8888, tries=10):
    for p in range(start, start + tries):
        try:
            with socket.socket() as s:
                s.bind(("127.0.0.1", p))
                return p
        except OSError:
            pass
    return None


class SpotifyAuthApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Spotify Refresh Token Grabber — Fih")
        self.root.geometry("560x580")
        self.root.resizable(False, False)
        self.root.configure(bg=BG)

        self.server      = None
        self.auth_code   = None
        self.refresh_tok = tk.StringVar()
        self.access_tok  = tk.StringVar()
        self.port        = 8888

        self._build_ui()

    # ── UI ──────────────────────────────────────────────────────────────
    def _build_ui(self):
        # Header
        hdr = tk.Frame(self.root, bg=BG)
        hdr.pack(fill="x", padx=24, pady=(20, 4))
        tk.Label(hdr, text="Spotify OAuth Key Grabber", bg=BG, fg=GREEN,
                 font=("Segoe UI", 15, "bold")).pack(anchor="w")
        tk.Label(hdr, text="Generates a permanent refresh token from your own Spotify Developer App.",
                 bg=BG, fg=SUBTEXT, font=FONT_UI).pack(anchor="w")

        # Setup guide
        guide = tk.Frame(self.root, bg=CARD, highlightbackground=BORDER, highlightthickness=1)
        guide.pack(fill="x", padx=24, pady=(10, 4))
        steps = [
            "1. Go to https://developer.spotify.com/dashboard and create an app.",
            f"2. Set Redirect URI to exactly:  {REDIRECT_URI}",
            "3. Copy your Client ID and Secret below.",
            "4. Click Authorize — log in and accept.",
        ]
        tk.Label(guide, text="Setup (one-time)", bg=CARD, fg=GREEN,
                 font=("Segoe UI", 9, "bold")).pack(anchor="w", padx=12, pady=(8, 2))
        for s in steps:
            tk.Label(guide, text=s, bg=CARD, fg=SUBTEXT,
                     font=("Segoe UI", 8)).pack(anchor="w", padx=16, pady=1)
        tk.Frame(guide, height=8, bg=CARD).pack()

        # Credentials
        cred = tk.Frame(self.root, bg=CARD, highlightbackground=BORDER, highlightthickness=1)
        cred.pack(fill="x", padx=24, pady=4)

        def field(parent, label, show=None):
            row = tk.Frame(parent, bg=CARD)
            row.pack(fill="x", padx=12, pady=5)
            tk.Label(row, text=label, bg=CARD, fg=TEXT,
                     font=FONT_UI, width=14, anchor="w").pack(side="left")
            e = tk.Entry(row, bg="#1e1e1e", fg=TEXT, insertbackground=TEXT,
                         relief="flat", font=FONT_MONO, show=show or "",
                         highlightbackground=BORDER, highlightthickness=1)
            e.pack(side="left", fill="x", expand=True)
            return e

        tk.Frame(cred, height=6, bg=CARD).pack()
        self.cid_entry = field(cred, "Client ID")
        self.sec_entry = field(cred, "Client Secret", show="•")
        tk.Frame(cred, height=6, bg=CARD).pack()

        # Status bar
        self.status_var = tk.StringVar(value="Ready — enter credentials and click Authorize.")
        status_bar = tk.Label(self.root, textvariable=self.status_var, bg="#111", fg=SUBTEXT,
                              font=("Segoe UI", 8), anchor="w", padx=12, pady=4)
        status_bar.pack(fill="x", padx=24, pady=(6, 0))

        # Auth button
        self.auth_btn = tk.Button(
            self.root, text="🔗  Authorize & Get Permanent Refresh Token",
            bg=GREEN, fg="#000000", font=("Segoe UI", 11, "bold"),
            relief="flat", cursor="hand2", activebackground=GREEN_HV,
            command=self.start_auth_flow
        )
        self.auth_btn.pack(pady=12, ipady=8, ipadx=16)

        # Output
        out = tk.Frame(self.root, bg=CARD, highlightbackground=BORDER, highlightthickness=1)
        out.pack(fill="both", expand=True, padx=24, pady=(0, 20))

        tk.Frame(out, height=8, bg=CARD).pack()

        self._token_field(out, "Refresh Token (Permanent):", self.refresh_tok,
                          "Copy Refresh Token", self._copy_refresh)

        tk.Frame(out, height=4, bg=CARD).pack()

        self._token_field(out, "Access Token (1-hour temp):", self.access_tok,
                          "Copy Access Token", self._copy_access)

        tk.Frame(out, height=4, bg=CARD).pack()

        # Combined copy
        combined_btn = tk.Button(
            out,
            text="📋  Copy Combined Paste  (refresh|clientId|clientSecret)",
            bg="#1e3a2a", fg=GREEN, font=("Segoe UI", 9, "bold"),
            relief="flat", cursor="hand2", activebackground="#1a3020",
            command=self._copy_combined
        )
        combined_btn.pack(fill="x", padx=12, pady=(4, 10), ipady=5)

    def _token_field(self, parent, label, var, btn_text, cmd):
        tk.Label(parent, text=label, bg=CARD, fg=SUBTEXT,
                 font=("Segoe UI", 8)).pack(anchor="w", padx=12)
        row = tk.Frame(parent, bg=CARD)
        row.pack(fill="x", padx=12, pady=2)
        box = tk.Entry(row, textvariable=var, bg="#1e1e1e", fg=GREEN,
                       insertbackground=TEXT, relief="flat", font=FONT_MONO,
                       readonlybackground="#1e1e1e", state="readonly",
                       highlightbackground=BORDER, highlightthickness=1)
        box.pack(side="left", fill="x", expand=True, ipady=4)
        btn = tk.Button(row, text=btn_text, bg="#282828", fg=TEXT,
                        font=("Segoe UI", 8, "bold"), relief="flat",
                        cursor="hand2", activebackground="#333",
                        command=cmd, padx=8)
        btn.pack(side="left", padx=(6, 0), ipady=4)

    # ── Clipboard ───────────────────────────────────────────────────────
    def _copy_refresh(self):
        t = self.refresh_tok.get().strip()
        if not t: return
        self.root.clipboard_clear(); self.root.clipboard_append(t)
        self._status("✓ Refresh token copied!", GREEN)

    def _copy_access(self):
        t = self.access_tok.get().strip()
        if not t: return
        self.root.clipboard_clear(); self.root.clipboard_append(t)
        self._status("✓ Access token copied!", GREEN)

    def _copy_combined(self):
        r = self.refresh_tok.get().strip()
        cid = self.cid_entry.get().strip()
        sec = self.sec_entry.get().strip()
        if not r:
            self._status("No refresh token yet — run auth first.", RED)
            return
        combined = f"{r}|{cid}|{sec}"
        self.root.clipboard_clear(); self.root.clipboard_append(combined)
        self._status("✓ Combined paste copied! Paste it directly into the Refresh Token box in-game.", GREEN)

    def _status(self, msg, color=SUBTEXT):
        self.status_var.set(msg)

    # ── Auth Flow ────────────────────────────────────────────────────────
    def start_auth_flow(self):
        cid = self.cid_entry.get().strip()
        sec = self.sec_entry.get().strip()

        if not cid or len(cid) < 8:
            messagebox.showerror("Missing", "Enter your Spotify Client ID.")
            return
        if not sec or len(sec) < 8:
            messagebox.showerror("Missing", "Enter your Spotify Client Secret.")
            return

        self.port = find_free_port(8888)
        if not self.port:
            messagebox.showerror("Port Error", "No free port found in range 8888–8897.")
            return

        global REDIRECT_URI
        REDIRECT_URI = f"http://127.0.0.1:{self.port}/callback"

        self.auth_btn.config(state="disabled", text="⏳  Waiting for browser authorization...")
        self.refresh_tok.set("")
        self.access_tok.set("")
        self._status("Browser opened — log in to Spotify and click Agree...")

        threading.Thread(target=self._auth_thread, args=(cid, sec), daemon=True).start()

    def _auth_thread(self, cid, sec):
        self.auth_code = None
        app = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                if "code" in params:
                    app.auth_code = params["code"][0]
                    html = b"""
                    <html><body style='background:#111;color:#1DB954;font-family:sans-serif;
                    display:flex;align-items:center;justify-content:center;height:100vh;margin:0'>
                    <div style='text-align:center'>
                    <h2>&#10003; Authorization Complete</h2>
                    <p style='color:#aaa'>You can close this tab and return to the tool.</p>
                    </div></body></html>"""
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html")
                    self.end_headers()
                    self.wfile.write(html)
                elif "error" in params:
                    app.auth_code = "__ERROR__"
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b"Authorization denied.")
                else:
                    self.send_response(400)
                    self.end_headers()

            def log_message(self, *a): pass

        try:
            srv = http.server.HTTPServer(("127.0.0.1", self.port), Handler)
        except OSError as e:
            self.root.after(0, lambda: messagebox.showerror("Port Error", str(e)))
            self.root.after(0, lambda: self.auth_btn.config(state="normal", text="🔗  Authorize & Get Permanent Refresh Token"))
            return

        params = {
            "client_id"     : cid,
            "response_type" : "code",
            "redirect_uri"  : REDIRECT_URI,
            "scope"         : SCOPES,
            "show_dialog"   : "true",
        }
        webbrowser.open("https://accounts.spotify.com/authorize?" + urllib.parse.urlencode(params))

        while self.auth_code is None:
            srv.handle_request()
        srv.server_close()

        if self.auth_code == "__ERROR__":
            self.root.after(0, lambda: self._status("Authorization denied by user.", RED))
            self.root.after(0, lambda: self.auth_btn.config(state="normal", text="🔗  Authorize & Get Permanent Refresh Token"))
            return

        self._exchange_code(cid, sec, self.auth_code)

    def _exchange_code(self, cid, sec, code):
        auth_b64 = base64.b64encode(f"{cid}:{sec}".encode()).decode()
        body = urllib.parse.urlencode({
            "grant_type"  : "authorization_code",
            "code"        : code,
            "redirect_uri": REDIRECT_URI,
        }).encode()

        req = urllib.request.Request(
            "https://accounts.spotify.com/api/token",
            data=body,
            headers={
                "Authorization": f"Basic {auth_b64}",
                "Content-Type" : "application/x-www-form-urlencoded",
            }
        )

        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read())
                rt = data.get("refresh_token", "")
                at = data.get("access_token", "")
                self.root.after(0, lambda: self._on_success(rt, at))
        except urllib.error.HTTPError as e:
            err = e.read().decode()
            self.root.after(0, lambda: self._on_error(err))
        except Exception as e:
            self.root.after(0, lambda: self._on_error(str(e)))

    def _on_success(self, rt, at):
        self.refresh_tok.set(rt)
        self.access_tok.set(at)
        self.auth_btn.config(state="normal", bg=GREEN,
                             text="✔  Token Acquired — Authorize Again")
        self._status(
            "✓ Success! Click 'Copy Combined Paste' and paste into the Refresh Token box in-game.",
            GREEN
        )

    def _on_error(self, err):
        self.auth_btn.config(state="normal", text="🔗  Authorize & Get Permanent Refresh Token")
        self._status(f"Error: {err}", RED)
        messagebox.showerror("Token Exchange Failed", err)


if __name__ == "__main__":
    root = tk.Tk()
    app = SpotifyAuthApp(root)
    root.mainloop()
