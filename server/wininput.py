"""Injection souris / clavier sous Windows via SendInput (ctypes, sans dépendance)."""
import ctypes
import subprocess
from ctypes import wintypes

user32 = ctypes.WinDLL("user32", use_last_error=True)

INPUT_MOUSE = 0
INPUT_KEYBOARD = 1

MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_HWHEEL = 0x1000

KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004

ULONG_PTR = ctypes.c_size_t


class MOUSEINPUT(ctypes.Structure):
    _fields_ = (
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    )


class KEYBDINPUT(ctypes.Structure):
    _fields_ = (
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    )


class HARDWAREINPUT(ctypes.Structure):
    _fields_ = (
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD),
    )


class _INPUTUNION(ctypes.Union):
    _fields_ = (("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT))


class INPUT(ctypes.Structure):
    _anonymous_ = ("u",)
    _fields_ = (("type", wintypes.DWORD), ("u", _INPUTUNION))


HKL = wintypes.HANDLE

user32.SendInput.argtypes = (wintypes.UINT, ctypes.POINTER(INPUT), ctypes.c_int)
user32.SendInput.restype = wintypes.UINT
user32.MapVirtualKeyW.argtypes = (wintypes.UINT, wintypes.UINT)
user32.MapVirtualKeyW.restype = wintypes.UINT
user32.VkKeyScanExW.argtypes = (wintypes.WCHAR, HKL)
user32.VkKeyScanExW.restype = ctypes.c_short
user32.GetForegroundWindow.restype = wintypes.HWND
user32.GetWindowThreadProcessId.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.DWORD))
user32.GetWindowThreadProcessId.restype = wintypes.DWORD
user32.GetKeyboardLayout.argtypes = (wintypes.DWORD,)
user32.GetKeyboardLayout.restype = HKL
user32.LockWorkStation.restype = wintypes.BOOL
user32.PostMessageW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM)
user32.PostMessageW.restype = wintypes.BOOL

# --------------------------------------------------------------------------- touches

VK = {
    "backspace": 0x08, "tab": 0x09, "enter": 0x0D, "shift": 0x10, "ctrl": 0x11, "alt": 0x12,
    "pause": 0x13, "capslock": 0x14, "esc": 0x1B, "space": 0x20, "pageup": 0x21,
    "pagedown": 0x22, "end": 0x23, "home": 0x24, "left": 0x25, "up": 0x26, "right": 0x27,
    "down": 0x28, "printscreen": 0x2C, "insert": 0x2D, "delete": 0x2E, "win": 0x5B,
    "menu": 0x5D, "num0": 0x60, "add": 0x6B, "subtract": 0x6D, "numlock": 0x90,
    "scrolllock": 0x91, "browser_back": 0xA6, "browser_forward": 0xA7,
    "browser_refresh": 0xA8, "browser_home": 0xAC, "volume_mute": 0xAD,
    "volume_down": 0xAE, "volume_up": 0xAF, "media_next": 0xB0, "media_prev": 0xB1,
    "media_stop": 0xB2, "media_play_pause": 0xB3,
}
for _i in range(1, 25):
    VK[f"f{_i}"] = 0x6F + _i

MODIFIERS = {"ctrl", "alt", "shift", "win"}

EXTENDED = {
    0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2C, 0x2D, 0x2E, 0x5B, 0x5C, 0x5D,
    0x6F, 0x90, 0xA3, 0xA5, *range(0xA6, 0xB8),
}

BUTTONS = {
    "l": (0x0002, 0x0004),
    "r": (0x0008, 0x0010),
    "m": (0x0020, 0x0040),
}


def _send(inputs):
    if not inputs:
        return
    for start in range(0, len(inputs), 200):
        chunk = inputs[start:start + 200]
        arr = (INPUT * len(chunk))(*chunk)
        user32.SendInput(len(chunk), arr, ctypes.sizeof(INPUT))


def _mouse(flags, dx=0, dy=0, data=0):
    i = INPUT()
    i.type = INPUT_MOUSE
    i.mi = MOUSEINPUT(dx, dy, data & 0xFFFFFFFF, flags, 0, 0)
    return i


def _vk_event(vk, up=False):
    flags = KEYEVENTF_KEYUP if up else 0
    if vk in EXTENDED:
        flags |= KEYEVENTF_EXTENDEDKEY
    scan = user32.MapVirtualKeyW(vk, 0) & 0xFF
    i = INPUT()
    i.type = INPUT_KEYBOARD
    i.ki = KEYBDINPUT(vk, scan, flags, 0, 0)
    return i


def _unicode_events(ch):
    out = []
    data = ch.encode("utf-16-le")
    for j in range(0, len(data), 2):
        unit = int.from_bytes(data[j:j + 2], "little")
        for up in (False, True):
            i = INPUT()
            i.type = INPUT_KEYBOARD
            i.ki = KEYBDINPUT(0, unit, KEYEVENTF_UNICODE | (KEYEVENTF_KEYUP if up else 0), 0, 0)
            out.append(i)
    return out


def _foreground_layout():
    hwnd = user32.GetForegroundWindow()
    tid = user32.GetWindowThreadProcessId(hwnd, None)
    return user32.GetKeyboardLayout(tid)


def resolve_key(name):
    """Retourne (vk, modificateurs_requis) pour un nom de touche ou un caractère."""
    if name in VK:
        return VK[name], ()
    if len(name) == 1:
        ch = name
        if "a" <= ch.lower() <= "z":
            return ord(ch.upper()), ()
        if "0" <= ch <= "9":
            return ord(ch), ()
        res = user32.VkKeyScanExW(ch, _foreground_layout())
        if res == -1:
            return None, ()
        vk = res & 0xFF
        state = (res >> 8) & 0xFF
        mods = []
        if state & 1:
            mods.append("shift")
        if state & 2:
            mods.append("ctrl")
        if state & 4:
            mods.append("alt")
        return vk, tuple(mods)
    return None, ()


class Controller:
    """État d'injection pour une connexion (touches et boutons maintenus)."""

    def __init__(self):
        self.held_keys = set()
        self.held_buttons = set()
        self._rx = 0.0
        self._ry = 0.0

    # ----------------------------------------------------------------- souris
    def move(self, dx, dy):
        self._rx += dx
        self._ry += dy
        ix, iy = int(self._rx), int(self._ry)
        if ix or iy:
            self._rx -= ix
            self._ry -= iy
            _send([_mouse(MOUSEEVENTF_MOVE, ix, iy)])

    def scroll(self, v, h):
        ev = []
        if v:
            ev.append(_mouse(MOUSEEVENTF_WHEEL, data=v))
        if h:
            ev.append(_mouse(MOUSEEVENTF_HWHEEL, data=h))
        _send(ev)

    def button(self, b, down):
        if b not in BUTTONS:
            return
        if down:
            self.held_buttons.add(b)
        else:
            self.held_buttons.discard(b)
        _send([_mouse(BUTTONS[b][0 if down else 1])])

    def click(self, b, n=1):
        if b not in BUTTONS:
            return
        d, u = BUTTONS[b]
        _send([_mouse(f) for _ in range(n) for f in (d, u)])

    def zoom(self, n):
        ev = []
        if VK["ctrl"] not in self.held_keys:
            ev.append(_vk_event(VK["ctrl"]))
        ev.append(_mouse(MOUSEEVENTF_WHEEL, data=120 * n))
        if VK["ctrl"] not in self.held_keys:
            ev.append(_vk_event(VK["ctrl"], up=True))
        _send(ev)

    # ---------------------------------------------------------------- clavier
    def key_down(self, name):
        vk, _ = resolve_key(name)
        if vk is None or vk in self.held_keys:
            return
        self.held_keys.add(vk)
        _send([_vk_event(vk)])

    def key_up(self, name):
        vk, _ = resolve_key(name)
        if vk is None or vk not in self.held_keys:
            return
        self.held_keys.discard(vk)
        _send([_vk_event(vk, up=True)])

    def key(self, name, mods=(), n=1):
        vk, needed = resolve_key(name)
        if vk is None:
            if len(name) == 1:
                self.text(name)
            return
        mod_vks = []
        for m in list(mods) + list(needed):
            mv = VK.get(m)
            if m in MODIFIERS and mv not in mod_vks and mv not in self.held_keys:
                mod_vks.append(mv)
        ev = [_vk_event(m) for m in mod_vks]
        for _ in range(n):
            ev += [_vk_event(vk), _vk_event(vk, up=True)]
        ev += [_vk_event(m, up=True) for m in reversed(mod_vks)]
        _send(ev)

    def text(self, s):
        ev = []
        s = s.replace("\r\n", "\n").replace("\r", "\n")
        for ch in s:
            if ch == "\n":
                ev += [_vk_event(VK["enter"]), _vk_event(VK["enter"], up=True)]
            elif ch == "\t":
                ev += [_vk_event(VK["tab"]), _vk_event(VK["tab"], up=True)]
            else:
                ev += _unicode_events(ch)
        _send(ev)

    def release_all(self):
        ev = [_vk_event(vk, up=True) for vk in self.held_keys]
        ev += [_mouse(BUTTONS[b][1]) for b in self.held_buttons]
        self.held_keys.clear()
        self.held_buttons.clear()
        _send(ev)


# ----------------------------------------------------------------- alimentation

POWER_ACTIONS = ("lock", "display_off", "sleep", "restart", "shutdown", "logoff")


def power(action):
    if action == "lock":
        user32.LockWorkStation()
    elif action == "display_off":
        # HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, 2 = éteint
        user32.PostMessageW(0xFFFF, 0x0112, 0xF170, 2)
    elif action == "sleep":
        ctypes.WinDLL("powrprof").SetSuspendState(False, False, False)
    elif action == "restart":
        subprocess.Popen(["shutdown", "/r", "/t", "0"])
    elif action == "shutdown":
        subprocess.Popen(["shutdown", "/s", "/t", "0"])
    elif action == "logoff":
        subprocess.Popen(["shutdown", "/l"])
