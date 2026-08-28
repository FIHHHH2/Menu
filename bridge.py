"""
FihUI Universal Media Bridge
Controls SoundCloud, Spotify (Free / Premium), YouTube Music, Apple Music, and any browser or desktop player.
Exposes local REST API on http://127.0.0.1:8974 for Roblox Executor in-game HUD and controls.

Requirements: Python 3.8+ (Zero extra dependencies required for basic media control)
Optional for real-time Windows metadata: pip install winsdk
"""

import sys
import os
import time
import json
import ctypes
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

PORT = 8974

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
        print(f"[!] keybd_event error: {e}")
        return False

# Try importing Windows SMTC SDK for rich metadata reading
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
    """Reads live track name and artist from Windows System Media Transport Controls."""
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
            print("[+] Media Action: NEXT TRACK")

        elif path in ('/prev', '/previous'):
            press_media_key(VK_MEDIA_PREV_TRACK)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "previous"}).encode())
            print("[+] Media Action: PREVIOUS TRACK")

        elif path in ('/playpause', '/play', '/pause'):
            press_media_key(VK_MEDIA_PLAY_PAUSE)
            self.send_response(200)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "action": "play_pause"}).encode())
            print("[+] Media Action: PLAY / PAUSE")

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
                "supported": ["SoundCloud", "Spotify Free", "YouTube Music", "Apple Music", "Browser Media"]
            }
            self.wfile.write(json.dumps(payload).encode())

        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"error": "not found"}).encode())

    def log_message(self, format, *args):
        return

def run_server():
    server = HTTPServer(('127.0.0.1', PORT), BridgeRequestHandler)
    print("=" * 60)
    print("  ✦ FihUI Universal Media Bridge Online ✦")
    print(f"  Listening on: http://127.0.0.1:{PORT}")
    print("  Compatible with: SoundCloud, Spotify Free, YouTube Music, Apple Music")
    if HAS_WINSDK:
        print("  [✓] Windows SMTC Metadata Engine Active")
    else:
        print("  [i] Tip: Run 'pip install winsdk' to enable real-time Windows track titles")
    print("=" * 60)
    
    if HAS_WINSDK:
        t = threading.Thread(target=smtc_polling_worker, daemon=True)
        t.start()

    server.serve_forever()

if __name__ == '__main__':
    run_server()