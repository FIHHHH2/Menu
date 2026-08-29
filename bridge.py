"""
FihUI Universal Media Bridge (Native Windows SMTC & System Tray App)
Dual Channel Transport:
1. File-Based Realtime IPC (readfile/writefile via executor workspace) - 100% Reliable, Zero Network Permission Block
2. Local REST API Server (http://127.0.0.1:8974)
"""

import sys
import os
import time
import json
import ctypes
import threading
import winreg
import asyncio
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

PORT = 8974
APP_NAME = "FihUI Media Bridge"
REG_RUN_PATH = r"Software\Microsoft\Windows\CurrentVersion\Run"

# Windows Virtual Key Codes fallback
VK_MEDIA_NEXT_TRACK = 0xB0
VK_MEDIA_PREV_TRACK = 0xB1
VK_MEDIA_PLAY_PAUSE = 0xB3
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP       = 0x0002

def press_physical_media_key(action):
    try:
        user32 = ctypes.windll.user32
        if action == "next":
            vk = VK_MEDIA_NEXT_TRACK
        elif action == "prev":
            vk = VK_MEDIA_PREV_TRACK
        else:
            vk = VK_MEDIA_PLAY_PAUSE

        user32.keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY, 0)
        time.sleep(0.04)
        user32.keybd_event(vk, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0)
        return True
    except Exception:
        return False

# ── WINRT NATIVE WINDOWS MEDIA CONTROLLER ───────────────────────────
HAS_WINRT = False
try:
    import winrt.windows.media.control as wmc
    HAS_WINRT = True
except ImportError:
    try:
        from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as wmc_mgr
        class WMCWrap:
            GlobalSystemMediaTransportControlsSessionManager = wmc_mgr
        wmc = WMCWrap()
        HAS_WINRT = True
    except ImportError:
        HAS_WINRT = False

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

_smtc_loop = None

async def _winrt_action(action):
    if not HAS_WINRT:
        press_physical_media_key(action)
        return

    try:
        manager = await wmc.GlobalSystemMediaTransportControlsSessionManager.request_async()
        if not manager:
            press_physical_media_key(action)
            return
        session = manager.get_current_session()
        if not session:
            press_physical_media_key(action)
            return

        if action == "next":
            ok = await session.try_skip_next_async()
            if not ok:
                press_physical_media_key("next")
        elif action == "prev":
            ok = await session.try_skip_previous_async()
            if not ok:
                press_physical_media_key("prev")
        elif action in ("playpause", "play_pause", "toggle"):
            ok = await session.try_toggle_play_pause_async()
            if not ok:
                press_physical_media_key("playpause")
        elif action == "play":
            await session.try_play_async()
        elif action == "pause":
            await session.try_pause_async()
    except Exception:
        press_physical_media_key(action)

def dispatch_media_command(action):
    """Executes media command on the background event loop."""
    global _smtc_loop
    if _smtc_loop and _smtc_loop.is_running():
        asyncio.run_coroutine_threadsafe(_winrt_action(action), _smtc_loop)
    else:
        press_physical_media_key(action)

async def _winrt_fetch_track():
    global current_track_state
    if not HAS_WINRT:
        return

    try:
        manager = await wmc.GlobalSystemMediaTransportControlsSessionManager.request_async()
        if not manager:
            return
        session = manager.get_current_session()
        if not session:
            return

        playback_info = session.get_playback_info()
        is_playing = False
        if playback_info:
            is_playing = (playback_info.playback_status == 4 or playback_info.playback_status == wmc.GlobalSystemMediaTransportControlsSessionPlaybackStatus.PLAYING)

        media_props = await session.try_get_media_properties_async()
        if media_props:
            title = media_props.title or ""
            artist = media_props.artist or ""
            album = media_props.album_title or ""

            if title or artist:
                timeline = session.get_timeline_properties()
                pos_ms = int(timeline.position.total_seconds() * 1000) if timeline and timeline.position else 0
                dur_ms = int(timeline.end_time.total_seconds() * 1000) if timeline and timeline.end_time else 0

                source_app = (session.source_app_user_model_id or "Media Player").lower()
                if any(b in source_app for b in ["chrome", "brave", "firefox", "msedge", "opera"]):
                    clean_source = "SoundCloud / Web"
                elif "spotify" in source_app:
                    clean_source = "Spotify"
                elif "apple" in source_app:
                    clean_source = "Apple Music"
                else:
                    clean_source = "Windows Media"

                current_track_state["name"] = title or "Unknown Track"
                current_track_state["artist"] = artist or "Unknown Artist"
                current_track_state["album"] = album
                current_track_state["isPlaying"] = is_playing
                current_track_state["progress_ms"] = pos_ms
                current_track_state["duration_ms"] = dur_ms
                current_track_state["source"] = clean_source
                current_track_state["last_update"] = time.time()
    except Exception:
        pass

# ── DUAL FILE-BASED IPC ENGINE (ZERO NETWORK BLOCKS) ────────────────
def get_all_workspace_paths():
    """Scans all known executor workspace folders."""
    candidates = []
    local_app = os.environ.get('LOCALAPPDATA', '')
    app_data = os.environ.get('APPDATA', '')
    user_prof = os.environ.get('USERPROFILE', '')

    paths = [
        os.path.join(local_app, "Potassium", "workspace"),
        os.path.join(local_app, "Hydrogen", "workspace"),
        os.path.join(local_app, "Wave", "workspace"),
        os.path.join(local_app, "Solara", "workspace"),
        os.path.join(local_app, "Synapse Z", "workspace"),
        os.path.join(local_app, "Celery", "workspace"),
        os.path.join(user_prof, ".synapse", "workspace"),
        os.path.join(local_app, "Roblox", "workspace"),
        os.getcwd()
    ]

    for p in paths:
        if os.path.exists(p) and p not in candidates:
            candidates.append(p)
    return candidates

def ipc_file_worker():
    """Watches for fih_bridge_cmd.txt in executor workspace folders and writes fih_bridge_state.json."""
    last_handled_id = ""
    while True:
        try:
            workspaces = get_all_workspace_paths()
            for ws in workspaces:
                # 1. Read command file
                cmd_file = os.path.join(ws, "fih_bridge_cmd.txt")
                if os.path.exists(cmd_file):
                    try:
                        with open(cmd_file, "r", encoding="utf-8") as f:
                            raw = f.read().strip()
                        if raw and raw != last_handled_id:
                            last_handled_id = raw
                            # format: action:timestamp e.g. "next:178798000"
                            parts = raw.split(":")
                            action = parts[0].lower()
                            dispatch_media_command(action)
                            # Remove processed command
                            try:
                                os.remove(cmd_file)
                            except Exception:
                                pass
                    except Exception:
                        pass

                # 2. Write track state file
                state_file = os.path.join(ws, "fih_bridge_state.json")
                try:
                    with open(state_file, "w", encoding="utf-8") as f:
                        json.dump(current_track_state, f)
                except Exception:
                    pass

        except Exception:
            pass
        time.sleep(0.08)

def smtc_worker():
    global _smtc_loop
    _smtc_loop = asyncio.new_event_loop()
    asyncio.set_event_loop(_smtc_loop)

    async def poll_loop():
        while True:
            await _winrt_fetch_track()
            await asyncio.sleep(0.8)

    _smtc_loop.run_until_complete(poll_loop())

# ── STARTUP REGISTRY ────────────────────────────────────────────────
def is_startup_enabled():
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_PATH, 0, winreg.KEY_READ)
        value, _ = winreg.QueryValueEx(key, APP_NAME)
        winreg.CloseKey(key)
        return True
    except WindowsError:
        return False

def set_startup_enabled(enable=True):
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_PATH, 0, winreg.KEY_SET_VALUE)
        if enable:
            if getattr(sys, 'frozen', False):
                cmd = f'"{sys.executable}"'
            else:
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
    except Exception:
        return False

# ── REST API SERVER ─────────────────────────────────────────────────
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
            dispatch_media_command("next")
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "next"}).encode())

        elif path in ('/prev', '/previous'):
            dispatch_media_command("prev")
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "previous"}).encode())

        elif path in ('/playpause', '/play', '/pause'):
            dispatch_media_command("playpause")
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
                "has_winrt": HAS_WINRT,
                "startup_enabled": is_startup_enabled(),
                "current_track": current_track_state["name"],
                "artist": current_track_state["artist"],
                "supported": ["Spotify Free/Premium", "SoundCloud", "YouTube Music", "Apple Music"]
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
    server = HTTPServer(('0.0.0.0', PORT), BridgeRequestHandler)
    server.serve_forever()

# ── SYSTEM TRAY ICON ────────────────────────────────────────────────
def create_tray_image():
    try:
        from PIL import Image, ImageDraw
        img = Image.new('RGBA', (64, 64), color=(0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle([4, 4, 60, 60], radius=12, fill=(20, 24, 34, 255), outline=(0, 160, 255, 255), width=2)
        draw.ellipse([16, 36, 28, 48], fill=(0, 220, 140, 255))
        draw.ellipse([36, 30, 48, 42], fill=(0, 220, 140, 255))
        draw.rectangle([26, 16, 30, 42], fill=(0, 220, 140, 255))
        draw.rectangle([46, 10, 50, 36], fill=(0, 220, 140, 255))
        draw.line([26, 16, 50, 10], fill=(0, 220, 140, 255), width=4)
        return img
    except ImportError:
        return None

def start_tray_app():
    # 1. Start SMTC polling thread
    if HAS_WINRT:
        smtc_t = threading.Thread(target=smtc_worker, daemon=True)
        smtc_t.start()

    # 2. Start File-IPC thread (Guaranteed channel for Roblox executors)
    ipc_t = threading.Thread(target=ipc_file_worker, daemon=True)
    ipc_t.start()

    # 3. Start HTTP server thread
    http_t = threading.Thread(target=run_http_server, daemon=True)
    http_t.start()

    try:
        import pystray
        from PIL import Image

        def toggle_startup_action(icon, item):
            cur = is_startup_enabled()
            set_startup_enabled(not cur)

        def play_pause_action(icon, item):
            dispatch_media_command("playpause")

        def next_action(icon, item):
            dispatch_media_command("next")

        def prev_action(icon, item):
            dispatch_media_command("prev")

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
        while True:
            time.sleep(1)

if __name__ == '__main__':
    start_tray_app()
