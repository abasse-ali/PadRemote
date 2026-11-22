"""PadRemote - serveur PC.

Transforme l'iPhone en pavé tactile, clavier et télécommande pour ce PC.
Sert la web app (dossier ../web) et reçoit les commandes via WebSocket.
Aucune dépendance externe : Python 3.9+ sous Windows suffit.
"""
import argparse
import asyncio
import base64
import hashlib
import json
import os
import re
import secrets
import socket
import struct
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path
from urllib.parse import quote, unquote

APP_DIR = Path(__file__).resolve().parent
WEB_DIR = (APP_DIR.parent / "web").resolve()
CONFIG_PATH = APP_DIR / "config.json"
LOG_PATH = APP_DIR / "padremote.log"
VERSION = "1.0"

# pythonw.exe (démarrage automatique) n'a pas de console : on écrit dans un fichier.
if sys.stdout is None or sys.stderr is None:
    _log_file = open(LOG_PATH, "a", encoding="utf-8", buffering=1)
    sys.stdout = sys.stderr = _log_file
else:
    try:
        sys.stdout.reconfigure(errors="replace")
    except AttributeError:
        pass

import bonjour  # noqa: E402  (après la redirection des sorties)
import wininput  # noqa: E402

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
MAX_FRAME = 1 << 20
MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".webmanifest": "application/manifest+json",
    ".json": "application/json",
}

CONFIG = {}
HOSTNAME = socket.gethostname()
_fails = {}  # ip -> [nb_echecs, bloque_jusqu_a]


def log(msg):
    print(time.strftime("[%H:%M:%S] ") + msg, flush=True)


# --------------------------------------------------------------------- config

def load_config(new_pin=False):
    cfg = {"port": 8765, "pin": "", "allow_power": True}
    try:
        cfg.update(json.loads(CONFIG_PATH.read_text("utf-8")))
    except FileNotFoundError:
        pass
    except ValueError:
        log("config.json illisible : valeurs par défaut utilisées.")
    cfg["pin"] = str(cfg.get("pin") or "")
    if new_pin or not re.fullmatch(r"\d{4,8}", cfg["pin"]):
        cfg["pin"] = f"{secrets.randbelow(10 ** 6):06d}"
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2, ensure_ascii=False), "utf-8")
    return cfg


def lan_ips():
    ips = []
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))  # aucun paquet envoyé : sert à trouver l'interface
        ips.append(s.getsockname()[0])
        s.close()
    except OSError:
        pass
    try:
        for ip in socket.gethostbyname_ex(HOSTNAME)[2]:
            if ip not in ips and not ip.startswith(("127.", "169.254.")):
                ips.append(ip)
    except OSError:
        pass
    return ips or ["127.0.0.1"]


def is_local(ip):
    return ip in ("127.0.0.1", "::1") or ip.startswith("::ffff:127.")


WOL_MACS = []  # adresses MAC pour le réveil (Wake-on-LAN), Ethernet en premier


def detect_wol_macs():
    """Adresses MAC des cartes réseau physiques, pour que l'iPhone puisse rallumer le PC."""
    script = (
        "[Console]::OutputEncoding = [Text.Encoding]::UTF8; "
        "Get-NetAdapter -Physical | Where-Object { $_.MacAddress } | "
        "Select-Object InterfaceDescription, MacAddress, PhysicalMediaType | ConvertTo-Json -Compress"
    )
    try:
        out = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True, encoding="utf-8", errors="replace", timeout=30,
            creationflags=0x08000000,  # CREATE_NO_WINDOW
        ).stdout
        data = json.loads(out or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    if isinstance(data, dict):
        data = [data]
    wired, wifi = [], []
    for adapter in data if isinstance(data, list) else []:
        desc = str(adapter.get("InterfaceDescription", ""))
        mac = str(adapter.get("MacAddress", "")).replace("-", ":").upper()
        media = str(adapter.get("PhysicalMediaType", ""))
        if not re.fullmatch(r"([0-9A-F]{2}:){5}[0-9A-F]{2}", mac):
            continue
        if re.search(r"apple|ndis|bluetooth|virtual|vpn|tap-|hyper-v|vmware|virtualbox", desc, re.I):
            continue
        (wifi if "802.11" in media else wired).append(mac)
    return wired + wifi


def _load_wol_macs():
    macs = detect_wol_macs()
    WOL_MACS[:] = macs
    if macs:
        log("Réveil à distance (Wake-on-LAN) : " + ", ".join(macs))


# ------------------------------------------------------------------ websocket

def _unmask(data, mask):
    n = len(data)
    m = (mask * (n // 4 + 1))[:n]
    return (int.from_bytes(data, "little") ^ int.from_bytes(m, "little")).to_bytes(n, "little")


def _frame(payload, opcode=0x1):
    n = len(payload)
    if n < 126:
        head = struct.pack("!BB", 0x80 | opcode, n)
    elif n < 65536:
        head = struct.pack("!BBH", 0x80 | opcode, 126, n)
    else:
        head = struct.pack("!BBQ", 0x80 | opcode, 127, n)
    return head + payload


class WebSocket:
    def __init__(self, reader, writer):
        self.r = reader
        self.w = writer
        self.closed = False

    async def recv(self):
        """Renvoie le prochain message texte, ou None si la connexion est fermée."""
        buf = bytearray()
        kind = None
        try:
            while True:
                b1, b2 = await self.r.readexactly(2)
                fin, op = b1 & 0x80, b1 & 0x0F
                n = b2 & 0x7F
                if n == 126:
                    (n,) = struct.unpack("!H", await self.r.readexactly(2))
                elif n == 127:
                    (n,) = struct.unpack("!Q", await self.r.readexactly(8))
                if n > MAX_FRAME:
                    return None
                mask = await self.r.readexactly(4) if b2 & 0x80 else b""
                payload = await self.r.readexactly(n) if n else b""
                if mask and payload:
                    payload = _unmask(payload, mask)
                if op == 0x8:  # close
                    await self.close()
                    return None
                if op == 0x9:  # ping
                    self.w.write(_frame(payload, 0xA))
                    await self.w.drain()
                    continue
                if op == 0xA:  # pong
                    continue
                if op in (0x1, 0x2):
                    kind, buf = op, bytearray(payload)
                elif op == 0x0:
                    buf += payload
                if fin:
                    if kind == 0x1:
                        return buf.decode("utf-8", "replace")
                    buf, kind = bytearray(), None
        except (asyncio.IncompleteReadError, ConnectionError, OSError):
            return None

    async def send(self, obj):
        if self.closed:
            return
        try:
            self.w.write(_frame(json.dumps(obj, separators=(",", ":")).encode()))
            await self.w.drain()
        except (ConnectionError, OSError):
            self.closed = True

    async def close(self):
        if self.closed:
            return
        self.closed = True
        try:
            self.w.write(_frame(b"\x03\xe8", 0x8))
            await self.w.drain()
        except (ConnectionError, OSError):
            pass


# ------------------------------------------------------------------- sessions

def _blocked(ip):
    f = _fails.get(ip)
    return bool(f and f[1] > time.time())


def _register_fail(ip):
    f = _fails.setdefault(ip, [0, 0.0])
    f[0] += 1
    if f[0] >= 5:
        f[0] = 0
        f[1] = time.time() + 60
        log(f"Trop d'essais de PIN depuis {ip} : bloqué 60 s.")


def _open_url(u):
    if isinstance(u, str) and len(u) < 4096 and re.match(r"^https?://\S+$", u, re.I):
        os.startfile(u)
        return True
    return False


def _num(v, lo, hi):
    v = float(v)
    if v != v:  # NaN
        return 0.0
    return max(lo, min(hi, v))


def dispatch(ctrl, msg):
    t = msg.get("t")
    if t == "m":
        ctrl.move(_num(msg.get("x", 0), -5000, 5000), _num(msg.get("y", 0), -5000, 5000))
    elif t == "s":
        ctrl.scroll(int(_num(msg.get("v", 0), -12000, 12000)), int(_num(msg.get("h", 0), -12000, 12000)))
    elif t == "c":
        ctrl.click(str(msg.get("b", "l")), int(_num(msg.get("n", 1), 1, 3)))
    elif t == "bd":
        ctrl.button(str(msg.get("b", "l")), True)
    elif t == "bu":
        ctrl.button(str(msg.get("b", "l")), False)
    elif t == "z":
        n = int(_num(msg.get("n", 0), -10, 10))
        if n:
            ctrl.zoom(n)
    elif t == "k":
        mods = msg.get("mods") or []
        if not isinstance(mods, list):
            mods = []
        ctrl.key(str(msg.get("k", "")), [str(m) for m in mods], int(_num(msg.get("n", 1), 1, 100)))
    elif t == "kd":
        ctrl.key_down(str(msg.get("k", "")))
    elif t == "ku":
        ctrl.key_up(str(msg.get("k", "")))
    elif t == "txt":
        ctrl.text(str(msg.get("s", ""))[:20000])


async def ws_session(reader, writer, headers, ip):
    key = headers.get("sec-websocket-key")
    if not key:
        await http_send(writer, 400, b"Bad Request", "text/plain")
        return
    accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
    writer.write(
        (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
        ).encode()
    )
    await writer.drain()
    ws = WebSocket(reader, writer)

    if _blocked(ip):
        await ws.send({"t": "err", "e": "blocked"})
        await ws.close()
        return
    try:
        first = await asyncio.wait_for(ws.recv(), 15)
    except asyncio.TimeoutError:
        await ws.close()
        return
    try:
        msg = json.loads(first or "")
    except ValueError:
        msg = {}
    pin = str(msg.get("pin", "")) if isinstance(msg, dict) else ""
    if not isinstance(msg, dict) or msg.get("t") != "auth" or not secrets.compare_digest(
        pin.encode(), CONFIG["pin"].encode()
    ):
        _register_fail(ip)
        log(f"PIN refusé pour {ip}")
        await ws.send({"t": "err", "e": "pin"})
        await ws.close()
        return
    _fails.pop(ip, None)

    await ws.send({
        "t": "ok", "name": HOSTNAME, "power": bool(CONFIG.get("allow_power", True)), "v": VERSION,
        "macs": list(WOL_MACS),
    })
    log(f"iPhone connecté : {ip}")
    ctrl = wininput.Controller()
    loop = asyncio.get_running_loop()
    try:
        while True:
            data = await ws.recv()
            if data is None:
                break
            try:
                msg = json.loads(data)
            except ValueError:
                continue
            if not isinstance(msg, dict):
                continue
            t = msg.get("t")
            try:
                if t == "p":
                    await ws.send({"t": "p", "i": msg.get("i")})
                elif t == "pw":
                    action = msg.get("a")
                    if not CONFIG.get("allow_power", True):
                        await ws.send({"t": "info", "m": "Actions d'alimentation désactivées sur le PC."})
                    elif action in wininput.POWER_ACTIONS:
                        log(f"Alimentation : {action}")
                        await ws.send({"t": "info", "m": "Commande envoyée au PC."})
                        loop.call_later(
                            0.4, lambda a=action: threading.Thread(target=wininput.power, args=(a,), daemon=True).start()
                        )
                elif t == "url":
                    ok = _open_url(msg.get("u"))
                    await ws.send({"t": "info", "m": "Page ouverte sur le PC." if ok else "Adresse invalide."})
                else:
                    dispatch(ctrl, msg)
            except (ValueError, TypeError, OSError) as e:
                log(f"Commande ignorée ({t}) : {e}")
    finally:
        ctrl.release_all()
        log(f"iPhone déconnecté : {ip}")


# ----------------------------------------------------------------------- http

async def http_send(writer, status, body, ctype, head_only=False):
    reason = {200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed"}
    head = (
        f"HTTP/1.1 {status} {reason.get(status, 'OK')}\r\n"
        f"Content-Type: {ctype}\r\nContent-Length: {len(body)}\r\n"
        "Cache-Control: no-cache\r\nX-Content-Type-Options: nosniff\r\n"
        "Connection: close\r\n\r\n"
    ).encode()
    writer.write(head if head_only else head + body)
    await writer.drain()


def pair_url(ip):
    return f"padremote://{ip}:{CONFIG['port']}?pin={CONFIG['pin']}&name={quote(HOSTNAME)}"


def pair_page():
    port = CONFIG["port"]
    ips = lan_ips()
    others = "".join(f"<li><code>{ip}</code> &nbsp;port <code>{port}</code></li>" for ip in ips)
    html = (APP_DIR / "pair.html").read_text("utf-8")
    return (
        html.replace("{{URL}}", pair_url(ips[0]))
        .replace("{{WEBURL}}", f"http://{ips[0]}:{port}/?k={CONFIG['pin']}")
        .replace("{{PIN}}", CONFIG["pin"])
        .replace("{{HOST}}", HOSTNAME)
        .replace("{{URLS}}", others)
        .encode()
    )


async def http_response(writer, method, path, ip):
    if method not in ("GET", "HEAD"):
        await http_send(writer, 405, b"Method Not Allowed", "text/plain")
        return
    head_only = method == "HEAD"
    if path == "/pair":
        if not is_local(ip):
            await http_send(writer, 403, b"Forbidden", "text/plain", head_only)
            return
        await http_send(writer, 200, pair_page(), MIME[".html"], head_only)
        return
    if path == "/":
        path = "/index.html"
    target = (WEB_DIR / unquote(path).lstrip("/")).resolve()
    if not target.is_relative_to(WEB_DIR) or not target.is_file():
        await http_send(writer, 404, b"Not Found", "text/plain", head_only)
        return
    ctype = MIME.get(target.suffix.lower(), "application/octet-stream")
    await http_send(writer, 200, target.read_bytes(), ctype, head_only)


async def handle_conn(reader, writer):
    peer = writer.get_extra_info("peername")
    ip = peer[0] if peer else "?"
    sock = writer.get_extra_info("socket")
    if sock is not None:
        try:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except OSError:
            pass
    try:
        try:
            raw = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 15)
        except (asyncio.IncompleteReadError, asyncio.LimitOverrunError, asyncio.TimeoutError, ConnectionError, OSError):
            return
        lines = raw.decode("latin-1").split("\r\n")
        parts = lines[0].split(" ")
        if len(parts) < 2:
            return
        method, target = parts[0], parts[1]
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()
        path = target.split("?", 1)[0]
        if path == "/ws" and "websocket" in headers.get("upgrade", "").lower():
            await ws_session(reader, writer, headers, ip)
        else:
            await http_response(writer, method, path, ip)
    except (ConnectionError, OSError):
        pass
    except Exception as e:  # ne jamais faire tomber le serveur
        log(f"Erreur : {e!r}")
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


# ----------------------------------------------------------------------- main

def _quiet_exceptions(loop, context):
    # Sous Windows, asyncio signale bruyamment les connexions coupées net (iPhone en veille…).
    if isinstance(context.get("exception"), (ConnectionResetError, ConnectionAbortedError)):
        return
    loop.default_exception_handler(context)


async def serve(host, port, open_browser):
    asyncio.get_running_loop().set_exception_handler(_quiet_exceptions)
    try:
        server = await asyncio.start_server(handle_conn, host, port)
    except OSError as e:
        log(f"Impossible d'écouter sur le port {port} ({e.strerror}).")
        log("PadRemote est peut-être déjà lancé ; sinon changez le port dans server/config.json.")
        if open_browser:
            webbrowser.open(f"http://127.0.0.1:{port}/pair")
        return 1

    threading.Thread(target=_load_wol_macs, name="wol", daemon=True).start()
    ips = lan_ips()
    mdns = bonjour.BonjourService(HOSTNAME, port, log=log)
    mdns_ok = host in ("0.0.0.0", "") and mdns.start()
    print()
    print("  PadRemote " + VERSION + " - télécommande iPhone pour ce PC")
    print("  " + "-" * 52)
    print("  Dans l'app PadRemote sur l'iPhone (même réseau) :")
    print(f"      PC : {HOSTNAME}" + ("  (détection automatique active)" if mdns_ok else ""))
    for ip in ips:
        print(f"      Adresse : {ip}   port : {port}")
    print(f"      Code PIN : {CONFIG['pin']}")
    print(f"  QR code d'appairage : http://127.0.0.1:{port}/pair")
    print("  Laissez cette fenêtre ouverte. Ctrl+C pour arrêter.")
    print()
    if open_browser:
        webbrowser.open(f"http://127.0.0.1:{port}/pair")
    try:
        async with server:
            await server.serve_forever()
    finally:
        mdns.stop()
    return 0


def main():
    global CONFIG
    ap = argparse.ArgumentParser(description="PadRemote - serveur PC")
    ap.add_argument("--host", default="0.0.0.0", help="adresse d'écoute (défaut : toutes)")
    ap.add_argument("--port", type=int, help="port (défaut : config.json, 8765)")
    ap.add_argument("--new-pin", action="store_true", help="générer un nouveau code PIN")
    ap.add_argument("--no-browser", action="store_true", help="ne pas ouvrir la page QR code")
    args = ap.parse_args()

    CONFIG = load_config(args.new_pin)
    if args.port:
        CONFIG["port"] = args.port
    try:
        return asyncio.run(serve(args.host, CONFIG["port"], not args.no_browser))
    except KeyboardInterrupt:
        log("Arrêt.")
        return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
