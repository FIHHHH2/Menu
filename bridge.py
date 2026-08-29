"""
FihUI Universal Media Bridge (Background Daemon & System Tray App)
Controls SoundCloud, Spotify (Free / Premium), YouTube Music, Apple Music, and any browser/desktop player.
Exposes local REST API on http://127.0.0.1:8974 for Roblox Executor in-game HUD and controls.

Features:
- Runs silently in background / system tray (no console window needed via pythonw.exe)
- System Tray menu (Status, Open on Startup toggle, Skip/Pause controls, Exit)
- Auto-start on Windows boot (Registry Run Key)
- Zero external dependencies required for core functionality (uses standard ctypes + winreg + http.server)
- Optional tray icon with pystray/PIL or lightweight Tkinter tray/background fallback
- Optional SMTC track metadata with winsdk
"""

import sys
import os
import time
import json
import ctypes
import threading
import winreg
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

PORT = 8974
APP_NAME = "FihUI Media Bridge"
REG_RUN_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"

# Windows Virtual Key Codes for Media Keys
VK_MEDIA_NEXT_TRACK = 0xB0
VK_MEDIA_PREV_TRACK = 0xB1
VK_MEDIA_STOP       = 0xB2
VK_MEDIA_PLAY_PAUSE = 0xB3
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP       = 0x0002

def press_media_key(vk_code):
    """Simulates physical media key press on Windows."""
    try:
        ctypes.windll.user32.keybd_event(vk_code, 0, KEYEVENTF_EXTENDEDKEY, 0)
        time.sleep(0.02)
        ctypes.windll.user32.keybd_event(vk_code, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0)
        return True
    except Exception as e:
        return False

# ── WINDOWS STARTUP REGISTRY HELPERS ─────────────────────────────────
def is_startup_enabled():
    """Checks if the bridge is set to run on Windows startup."""
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_PATH, 0, winreg.KEY_READ)
        value, _ = winreg.QueryValueEx(key, APP_NAME)
        winreg.CloseKey(key)
        return True
    except WindowsError:
        return False

def set_startup_enabled(enable=True):
    """Adds or removes the bridge from the Windows startup registry."""
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_PATH, 0, winreg.KEY_SET_VALUE)
        if enable:
            # Prefer pythonw.exe if available so it starts completely silent without a cmd window
            python_exe = sys.executable
            if python_exe.lower().endswith("python.exe"):
                w_exe = python_exe[:-10] + "pythonw.exe"
                if os.path.exists(w_exe):
                    python_exe = w_exe
            script_path = os.path.abspath(__file__)
            cmd = f'"{python_exe}" "{script_path}" --silent'
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, cmd)
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
            except WindowsError:
                pass
        winreg.CloseKey(key)
        return True
    except Exception as e:
        return False

# ── WINDOWS SMTC METADATA READER ─────────────────────────────────────
HAS_WINSDK = False
try:
    import asyncio
    from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SMTCManager
    HAS_WINSDK = True
except ImportError:
    HAS_WINSDK = False

current_track_state = {
    "name": "Local Audio Session",
    "artist": "SoundCloud / Spotify / Browser",
    "album": "",
    "cover": "",
    "isPlaying": True,
    "source": "Local Bridge",
    "progress_ms": 0,
    "duration_ms": 0,
    "last_update": time.time()
}

async def fetch_smtc_metadata():
    global current_track_state
    try:
        manager = await SMTCManager.request_async()
        if not manager:
            return
        session = manager.get_current_session()
        if not session:
            return

        playback_info = session.get_playback_info()
        is_playing = False
        if playback_info:
            is_playing = (playback_info.playback_status == 4)

        media_props = await session.try_get_media_properties_async()
        if media_props:
            title = media_props.title or "Unknown Track"
            artist = media_props.artist or "Unknown Artist"
            album = media_props.album_title or ""

            timeline = session.get_timeline_properties()
            pos_ms = int(timeline.position.total_seconds() * 1000) if timeline else 0
            dur_ms = int(timeline.end_time.total_seconds() * 1000) if timeline else 0

            source_app = (session.source_app_user_model_id or "Media Player").lower()
            if any(b in source_app for b in ["chrome", "brave", "firefox", "msedge", "opera"]):
                clean_source = "SoundCloud / Web"
            elif "spotify" in source_app:
                clean_source = "Spotify"
            else:
                clean_source = "Windows Media"

            current_track_state["name"] = title
            current_track_state["artist"] = artist
            current_track_state["album"] = album
            current_track_state["isPlaying"] = is_playing
            current_track_state["progress_ms"] = pos_ms
            current_track_state["duration_ms"] = dur_ms
            current_track_state["source"] = clean_source
            current_track_state["last_update"] = time.time()
    except Exception:
        pass

def smtc_polling_worker():
    if not HAS_WINSDK:
        return
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    while True:
        try:
            loop.run_until_complete(fetch_smtc_metadata())
        except Exception:
            pass
        time.sleep(1.5)

# ── HTTP REST SERVER ────────────────────────────────────────────────
class BridgeRequestHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Content-Type', 'application/json')

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path.lower()

        if path == '/next':
            press_media_key(VK_MEDIA_NEXT_TRACK)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "next"}).encode())

        elif path in ('/prev', '/previous'):
            press_media_key(VK_MEDIA_PREV_TRACK)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "previous"}).encode())

        elif path in ('/playpause', '/play', '/pause'):
            press_media_key(VK_MEDIA_PLAY_PAUSE)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "play_pause"}).encode())

        elif path in ('/current', '/track'):
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(current_track_state).encode())

        elif path in ('/status', '/ping'):
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            payload = {
                "status": "online",
                "port": PORT,
                "has_winsdk": HAS_WINSDK,
                "startup_enabled": is_startup_enabled(),
                "supported": ["SoundCloud", "Spotify Free", "YouTube Music", "Apple Music", "Browser Media"]
            }
            self.wfile.write(json.dumps(payload).encode())

        elif path == '/autostart/toggle':
            cur = is_startup_enabled()
            set_startup_enabled(not cur)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "startup_enabled": not cur}).encode())

        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode())

    def log_message(self, format, *args):
        return

def run_http_server():
    server = HTTPServer(('127.0.0.1', PORT), BridgeRequestHandler)
    server.serve_forever()

# ── SYSTEM TRAY ICON & BACKGROUND RUNNER ────────────────────────────
def create_tray_image():
    """Generates a clean 64x64 musical note icon in memory using PIL or raw bitmap."""
    try:
        from PIL import Image, ImageDraw
        img = Image.new('RGBA', (64, 64), color=(0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        # Rounded background box
        draw.rounded_rectangle([4, 4, 60, 60], radius=12, fill=(20, 24, 34, 255), outline=(0, 160, 255, 255), width=2)
        # Musical note
        draw.ellipse([16, 36, 28, 48], fill=(0, 220, 140, 255))
        draw.ellipse([36, 30, 48, 42], fill=(0, 220, 140, 255))
        draw.rectangle([26, 16, 30, 42], fill=(0, 220, 140, 255))
        draw.rectangle([46, 10, 50, 36], fill=(0, 220, 140, 255))
        draw.line([26, 16, 50, 10], fill=(0, 220, 140, 255), width=4)
        return img
    except ImportError:
        return None

def start_tray_app():
    """Runs system tray app with background daemon."""
    # Start HTTP server thread
    http_thread = threading.Thread(target=run_http_server, daemon=True)
    http_thread.start()

    # Start SMTC polling thread
    if HAS_WINSDK:
        smtc_thread = threading.Thread(target=smtc_polling_worker, daemon=True)
        smtc_thread.start()

    # Try loading pystray for real system tray icon in notification area
    try:
        import pystray
        from PIL import Image

        def toggle_startup_action(icon, item):
            cur = is_startup_enabled()
            set_startup_enabled(not cur)

        def play_pause_action(icon, item):
            press_media_key(VK_MEDIA_PLAY_PAUSE)

        def next_action(icon, item):
            press_media_key(VK_MEDIA_NEXT_TRACK)

        def prev_action(icon, item):
            press_media_key(VK_MEDIA_PREV_TRACK)

        def exit_action(icon, item):
            icon.stop()
            os._exit(0)

        img = create_tray_image()
        if not img:
            img = Image.new('RGB', (64, 64), color=(0, 160, 255))

        menu = pystray.Menu(
            pystray.MenuItem("FihUI Media Bridge (Online :8974)", None, enabled=False),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("⏯  Play / Pause", play_pause_action),
            pystray.MenuItem("⏭  Next Track", next_action),
            pystray.MenuItem("⏮  Previous Track", prev_action),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem(
                "Run on Windows Startup",
                toggle_startup_action,
                checked=lambda item: is_startup_enabled()
            ),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Exit Bridge", exit_action)
        )

        icon = pystray.Icon("FihUIMediaBridge", img, "FihUI Media Bridge (Port 8974)", menu)
        icon.run()

    except ImportError:
        # Fallback to headless background loop if pystray is not installed
        print("=" * 60)
        print(f"  ✦ {APP_NAME} Online (Headless Background Daemon) ✦")
        print(f"  Listening on: http://127.0.0.1:{PORT}")
        print(f"  Run on Startup: {'[✓] Enabled' if is_startup_enabled() else '[ ] Disabled'}")
        print("  Tip: Run 'pip install pystray pillow' to enable the taskbar tray icon")
        print("=" * 60)
        while True:
            time.sleep(1)

if __name__ == '__main__':
    # Auto-hide console window on Windows if started without pythonw
    if "--silent" in sys.argv:
        try:
            ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)
        except Exception:
            pass

    start_tray_app()
