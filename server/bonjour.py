"""Répondeur Bonjour (mDNS / DNS-SD) minimal, en Python pur.

Annonce le service « _padremote._tcp » pour que l'app iPhone trouve le PC toute seule,
même si son adresse IP change. Cohabite avec le service mDNS de Windows (SO_REUSEADDR).
"""
import socket
import struct
import threading
import time

GROUP = "224.0.0.251"
MDNS_PORT = 5353
SERVICE = "_padremote._tcp.local"
ENUM = "_services._dns-sd._udp.local"
T_A, T_PTR, T_TXT, T_SRV, T_ANY = 1, 12, 16, 33, 255


def _encode_name(name):
    out = b""
    for label in name.strip(".").split("."):
        raw = label.encode("utf-8")[:63]
        out += bytes([len(raw)]) + raw
    return out + b"\0"


def _read_name(buf, off):
    labels, end, jumps = [], None, 0
    while True:
        ln = buf[off]
        if ln == 0:
            off += 1
            break
        if ln & 0xC0 == 0xC0:
            if end is None:
                end = off + 2
            off = struct.unpack("!H", buf[off:off + 2])[0] & 0x3FFF
            jumps += 1
            if jumps > 20:
                raise ValueError("boucle de compression")
            continue
        labels.append(buf[off + 1:off + 1 + ln].decode("utf-8", "replace"))
        off += 1 + ln
    return ".".join(labels), (end if end is not None else off)


def _rr(name, rtype, ttl, rdata, unique=False):
    cls = 1 | (0x8000 if unique else 0)
    return _encode_name(name) + struct.pack("!HHIH", rtype, cls, ttl, len(rdata)) + rdata


def _route_ip(dest):
    """Adresse locale utilisée pour joindre `dest`."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect((dest, MDNS_PORT))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return None


def _local_ips():
    ips = []
    for probe in ("8.8.8.8",):
        ip = _route_ip(probe)
        if ip:
            ips.append(ip)
    try:
        for ip in socket.gethostbyname_ex(socket.gethostname())[2]:
            if ip not in ips and not ip.startswith(("127.", "169.254.")):
                ips.append(ip)
    except OSError:
        pass
    return ips


class BonjourService:
    def __init__(self, instance, port, log=print):
        host = socket.gethostname()
        safe = "".join(c if c.isalnum() or c == "-" else "-" for c in host)[:40] or "pc"
        self.instance = instance.replace(".", "-")[:60]
        self.full = f"{self.instance}.{SERVICE}"
        self.target = f"padremote-{safe}.local"
        self.port = port
        self.log = log
        self.sock = None
        self.running = False

    # ---------------------------------------------------------------- réponses
    def _records(self, ip, ttl, unicast=False):
        uniq = not unicast
        ptr = _rr(SERVICE, T_PTR, ttl, _encode_name(self.full))
        srv = _rr(self.full, T_SRV, ttl, struct.pack("!HHH", 0, 0, self.port) + _encode_name(self.target), uniq)
        txt = _rr(self.full, T_TXT, ttl, b"\x03v=1", uniq)
        a = _rr(self.target, T_A, ttl, socket.inet_aton(ip), uniq)
        return ptr, srv, txt, a

    def _send(self, packet, dest, ip):
        try:
            self.sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(ip))
            self.sock.sendto(packet, dest)
        except OSError:
            pass

    def _announce(self, ttl=120):
        for ip in _local_ips():
            ptr, srv, txt, a = self._records(ip, ttl)
            pkt = struct.pack("!HHHHHH", 0, 0x8400, 0, 4, 0, 0) + ptr + srv + txt + a
            self._send(pkt, (GROUP, MDNS_PORT), ip)

    def _handle(self, data, addr):
        if len(data) < 12:
            return
        qid, flags, qd = struct.unpack("!HHH", data[:6])
        if flags & 0x8000:  # réponse d'un autre appareil
            return
        legacy = addr[1] != MDNS_PORT  # requête « unicast classique » : on répond directement
        ip = _route_ip(addr[0]) or (_local_ips() or [None])[0]
        if not ip:
            return
        ttl = 10 if legacy else 120
        ptr, srv, txt, a = self._records(ip, ttl, unicast=legacy)
        answers, extra, questions, unicast_wanted = [], [], [], legacy
        off = 12
        for _ in range(qd):
            name, off = _read_name(data, off)
            qtype, qclass = struct.unpack("!HH", data[off:off + 4])
            off += 4
            n = name.lower().rstrip(".")
            hit = False
            if n == SERVICE.lower() and qtype in (T_PTR, T_ANY):
                answers.append(ptr)
                extra += [srv, txt, a]
                hit = True
            elif n == self.full.lower() and qtype in (T_SRV, T_TXT, T_ANY):
                answers += [srv] if qtype == T_SRV else [txt] if qtype == T_TXT else [srv, txt]
                extra.append(a)
                hit = True
            elif n == self.target.lower() and qtype in (T_A, T_ANY):
                answers.append(a)
                hit = True
            elif n == ENUM.lower() and qtype in (T_PTR, T_ANY):
                answers.append(_rr(ENUM, T_PTR, ttl, _encode_name(SERVICE)))
                hit = True
            if hit:
                questions.append(_encode_name(name) + struct.pack("!HH", qtype, 1))
                if qclass & 0x8000:
                    unicast_wanted = True
        if not answers:
            return
        extra = [r for i, r in enumerate(extra) if r not in answers and r not in extra[:i]]
        if legacy:
            pkt = struct.pack("!HHHHHH", qid, 0x8400, len(questions), len(answers), 0, len(extra))
            pkt += b"".join(questions) + b"".join(answers) + b"".join(extra)
            self._send(pkt, addr, ip)
        else:
            pkt = struct.pack("!HHHHHH", 0, 0x8400, 0, len(answers), 0, len(extra))
            pkt += b"".join(answers) + b"".join(extra)
            self._send(pkt, addr if unicast_wanted else (GROUP, MDNS_PORT), ip)

    # ------------------------------------------------------------------ cycle
    def start(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind(("", MDNS_PORT))
            s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
            s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
            s.settimeout(1.0)
        except OSError as e:
            self.log(f"Bonjour indisponible ({e}). Connexion par adresse IP uniquement.")
            return False
        joined = 0
        for ip in _local_ips():
            try:
                s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, socket.inet_aton(GROUP) + socket.inet_aton(ip))
                joined += 1
            except OSError:
                pass
        if not joined:
            s.close()
            self.log("Bonjour : aucune interface réseau disponible.")
            return False
        self.sock = s
        self.running = True
        threading.Thread(target=self._loop, name="bonjour", daemon=True).start()
        return True

    def _loop(self):
        next_announce = time.time()
        announces = 0
        while self.running:
            if announces < 3 and time.time() >= next_announce:
                self._announce()
                announces += 1
                next_announce = time.time() + 1.0 * announces
            try:
                data, addr = self.sock.recvfrom(9000)
            except socket.timeout:
                continue
            except OSError:
                if not self.running:
                    break
                continue
            try:
                self._handle(data, addr)
            except (ValueError, IndexError, struct.error):
                pass

    def stop(self):
        if not self.running:
            return
        self.running = False
        try:
            self._announce(ttl=0)  # « au revoir » : retire le service des caches
            self.sock.close()
        except OSError:
            pass
