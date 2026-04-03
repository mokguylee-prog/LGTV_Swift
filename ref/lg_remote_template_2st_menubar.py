"""
LG NetCast TV 네트워크 리모컨 템플릿
대상: LG NetCast TV (Legacy HDCP API)
프로토콜: HTTP POST / XML / port 8080

흐름:
  1. IP 입력 (또는 네트워크 스캔)
  2. 페어링 키 요청 → TV 화면에 PIN 표시
  3. PIN 입력 → session 획득
  4. 리모컨 버튼으로 TV 제어
"""

import argparse
import os
import plistlib
import subprocess
import sys
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import socket
import concurrent.futures
import json
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib import error, request

from lg_keymap import KEY_CODE
from lg_remote_template_2st_skin import APP_BG, build_remote_panel as build_skin_remote_panel

# ──────────────────────────────────────────────
# 상수
# ──────────────────────────────────────────────

PORT = 8080
BASE_URL_TMPL = "http://{ip}:8080/hdcp/api"
DEFAULT_PIN = "SMKBWA"
UDAP_SEARCH_TARGET = "udap:rootservice"
UPNP_ROOT_TARGET = "upnp:rootdevice"
MEDIA_RENDERER_TARGET = "urn:schemas-upnp-org:device:MediaRenderer:1"
SSDP_ALL_TARGET = "ssdp:all"
SSDP_ADDR = "239.255.255.250"
SSDP_PORT = 1900
BSEARCH_ADDR = "255.255.255.255"
BSEARCH_PORT = 1990
DISCOVERY_TIMEOUT = 3.5
DESCRIPTION_TIMEOUT = 3.0
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "LG NetCast Remote 2st Menubar"
LEGACY_STATE_PATH = Path(__file__).with_name("lg_remote_template_2st_state.json")
STATE_PATH = APP_SUPPORT_DIR / "lg_remote_template_2st_state.json"
ASSETS_DIR = Path(__file__).resolve().parent / "assets"
MENUBAR_APP_LABEL = "com.kadelee.lgnetcast.2st.menubar"
WINDOW_CONTROL_PORT = 48543

HEADERS = {
    "Content-Type": "application/atom+xml",
    "Accept": "application/atom+xml",
    "User-Agent": "iPhone",
    "Connection": "close",
}

def _ensure_state_dir():
    APP_SUPPORT_DIR.mkdir(parents=True, exist_ok=True)


def _migrate_legacy_state_if_needed():
    if STATE_PATH.exists() or not LEGACY_STATE_PATH.exists():
        return
    try:
        _ensure_state_dir()
        STATE_PATH.write_text(
            LEGACY_STATE_PATH.read_text(encoding="utf-8"),
            encoding="utf-8",
        )
    except OSError:
        pass


def _load_saved_state() -> dict:
    _migrate_legacy_state_if_needed()
    try:
        payload = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return {}
    if not isinstance(payload, dict):
        return {}
    return payload


def _load_saved_tv_ip() -> str:
    payload = _load_saved_state()
    return str(payload.get("tv_ip", "")).strip()


def _load_saved_pin() -> str:
    payload = _load_saved_state()
    return str(payload.get("pin", "")).strip()


def _save_state(tv_ip: str | None = None, pin: str | None = None):
    _ensure_state_dir()
    payload = _load_saved_state()
    if tv_ip is not None:
        payload["tv_ip"] = tv_ip
    if pin is not None:
        payload["pin"] = pin
    payload["saved_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    STATE_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _save_tv_ip(ip: str):
    try:
        _save_state(tv_ip=ip)
    except OSError:
        pass


def _save_pin(pin: str):
    try:
        _save_state(pin=pin)
    except OSError:
        pass


def _clear_saved_tv_ip():
    try:
        payload = _load_saved_state()
        if "tv_ip" in payload:
            payload.pop("tv_ip", None)
            payload["saved_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
            STATE_PATH.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
    except OSError:
        pass


def _apply_runtime_icon(root: tk.Tk):
    icon_path = ASSETS_DIR / "lg_remote_256.png"
    if icon_path.exists():
        try:
            root._icon_image = tk.PhotoImage(file=str(icon_path))
            root.iconphoto(True, root._icon_image)
        except Exception:
            pass

        try:
            from AppKit import NSApplication, NSImage

            image = NSImage.alloc().initWithContentsOfFile_(str(icon_path))
            if image is not None:
                NSApplication.sharedApplication().setApplicationIconImage_(image)
        except Exception:
            pass


def _resource_path(*parts: str) -> str:
    base_dir = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return str(base_dir.joinpath(*parts))


def _current_launch_command(window_mode: bool = False) -> list[str]:
    if getattr(sys, "frozen", False):
        command = [sys.executable]
    else:
        command = [sys.executable, str(Path(__file__).resolve())]
    if window_mode:
        command.append("--window")
    return command


def _notify_existing_window() -> bool:
    try:
        with socket.create_connection(("127.0.0.1", WINDOW_CONTROL_PORT), timeout=0.35) as sock:
            sock.sendall(b"SHOW\n")
        return True
    except OSError:
        return False


def _launch_agent_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"{MENUBAR_APP_LABEL}.plist"


def _login_item_enabled() -> bool:
    return _launch_agent_path().exists()


def install_login_item() -> Path:
    launch_agent_path = _launch_agent_path()
    launch_agent_path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "Label": MENUBAR_APP_LABEL,
        "ProgramArguments": _current_launch_command(window_mode=False),
        "RunAtLoad": True,
        "KeepAlive": False,
        "ProcessType": "Interactive",
        "StandardOutPath": str(Path.home() / "Library" / "Logs" / "lg_netcast_2st_menubar.out.log"),
        "StandardErrorPath": str(Path.home() / "Library" / "Logs" / "lg_netcast_2st_menubar.err.log"),
    }

    with launch_agent_path.open("wb") as fh:
        plistlib.dump(payload, fh)

    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", domain, str(launch_agent_path)], check=False)
    subprocess.run(["launchctl", "bootstrap", domain, str(launch_agent_path)], check=False)
    return launch_agent_path


def remove_login_item() -> Path:
    launch_agent_path = _launch_agent_path()
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", domain, str(launch_agent_path)], check=False)
    if launch_agent_path.exists():
        launch_agent_path.unlink()
    return launch_agent_path


def _configure_macos_accessory_mode():
    try:
        from AppKit import NSApplication, NSApplicationActivationPolicyAccessory

        NSApplication.sharedApplication().setActivationPolicy_(NSApplicationActivationPolicyAccessory)
    except Exception:
        pass

# ──────────────────────────────────────────────
# API 함수
# ──────────────────────────────────────────────

def _post_xml(ip: str, endpoint: str, body: str) -> tuple[int, str]:
    """Legacy HDCP XML POST 요청 후 HTTP 상태 코드와 응답 본문 반환."""
    url = f"{BASE_URL_TMPL.format(ip=ip)}/{endpoint}"
    req = request.Request(
        url,
        data=body.encode("utf-8"),
        headers=HEADERS,
        method="POST",
    )

    try:
        with request.urlopen(req, timeout=5) as resp:
            return resp.status, resp.read().decode("utf-8", errors="ignore")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore").strip()
        if detail:
            raise ConnectionError(f"HTTP {exc.code}: {detail}")
        raise ConnectionError(f"HTTP {exc.code}: {exc.reason}")
    except (error.URLError, TimeoutError, OSError) as exc:
        reason = getattr(exc, "reason", exc)
        raise ConnectionError(f"연결 오류: {reason}")


def _parse_xml(xml_text: str) -> ET.Element | None:
    xml_text = xml_text.strip()
    if not xml_text:
        return None
    try:
        return ET.fromstring(xml_text)
    except ET.ParseError:
        return None


def _http_get_text(url: str, timeout: float = DESCRIPTION_TIMEOUT) -> str:
    req = request.Request(url, headers={"User-Agent": "UDAP/2.0"}, method="GET")
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except error.HTTPError as exc:
        raise ConnectionError(f"HTTP {exc.code}: {exc.reason}")
    except (error.URLError, TimeoutError, OSError) as exc:
        reason = getattr(exc, "reason", exc)
        raise ConnectionError(f"연결 오류: {reason}")


def _parse_ssdp_headers(packet: bytes) -> dict[str, str]:
    text = packet.decode("utf-8", errors="ignore")
    lines = [line.strip() for line in text.replace("\r\n", "\n").split("\n") if line.strip()]
    if not lines or not lines[0].startswith("HTTP/1.1 200"):
        return {}

    headers: dict[str, str] = {}
    for line in lines[1:]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        headers[key.strip().lower()] = value.strip()
    return headers


def _parse_device_description(xml_text: str) -> dict | None:
    root = _parse_xml(xml_text)
    if root is None:
        return None

    manufacturer = root.findtext(".//manufacturer", "").strip()
    device_type = root.findtext(".//deviceType", "").strip()
    model_name = root.findtext(".//modelName", "").strip()
    friendly_name = root.findtext(".//friendlyName", "").strip()
    model_description = root.findtext(".//modelDescription", "").strip()
    comm_port = root.findtext(".//port", "").strip()
    services = [
        (service.attrib.get("name") or "").strip()
        for service in root.findall(".//serviceList/service")
        if (service.attrib.get("name") or "").strip()
    ]

    manufacturer_upper = manufacturer.upper()
    device_type_upper = device_type.upper()
    name_blob = " ".join([model_name, friendly_name, model_description]).upper()
    manufacturer_ok = "LG" in manufacturer_upper
    tv_hint = (
        "TV" in device_type_upper
        or "MEDIARENDERER" in device_type_upper
        or "TV" in name_blob
        or "LW5700" in name_blob
        or "SMART TV" in name_blob
    )
    return {
        "manufacturer": manufacturer,
        "device_type": device_type,
        "model_name": model_name,
        "friendly_name": friendly_name,
        "model_description": model_description,
        "port": comm_port,
        "services": services,
        "is_lg_tv": manufacturer_ok and tv_hint,
    }


def _device_label(ip: str, details: dict, verified: bool) -> str:
    if verified:
        name_bits = [bit for bit in (details.get("friendly_name"), details.get("model_name")) if bit]
        suffix = f" {' / '.join(name_bits)}" if name_bits else ""
        return f"{ip}  [LG TV 확인]{suffix}"
    return f"{ip}  [port 8080 / LG TV 미확인]"


def _build_search_packet(method: str, host: str, port: int, search_target: str) -> bytes:
    return (
        f"{method} * HTTP/1.1\r\n"
        f"HOST: {host}:{port}\r\n"
        'MAN: "ssdp:discover"\r\n'
        "MX: 3\r\n"
        f"ST: {search_target}\r\n"
        "USER-AGENT: UDAP/2.0\r\n"
        "\r\n"
    ).encode("utf-8")


def _discover_hosts(method: str, host: str, port: int, search_target: str, timeout: float) -> list[dict]:
    packet = _build_search_packet(method, host, port, search_target)
    seen: dict[str, dict] = {}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    try:
        sock.settimeout(0.35)
        sock.bind(("", 0))
        if method == "B-SEARCH":
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        else:
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
        sock.sendto(packet, (host, port))

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                data, addr = sock.recvfrom(8192)
            except socket.timeout:
                continue
            except OSError:
                break

            headers = _parse_ssdp_headers(data)
            if not headers:
                continue
            headers["ip"] = addr[0]
            headers["search_target"] = search_target
            seen[addr[0]] = headers
    finally:
        sock.close()

    return list(seen.values())


def discover_lg_tvs(progress_cb=None) -> list[dict]:
    steps = [
        ("M-SEARCH", SSDP_ADDR, SSDP_PORT, [MEDIA_RENDERER_TARGET, UPNP_ROOT_TARGET, SSDP_ALL_TARGET, UDAP_SEARCH_TARGET], "SSDP M-SEARCH로 LG TV 검색 중…"),
        ("B-SEARCH", BSEARCH_ADDR, BSEARCH_PORT, [MEDIA_RENDERER_TARGET, UPNP_ROOT_TARGET, UDAP_SEARCH_TARGET], "M-SEARCH 응답 부족, B-SEARCH로 재시도 중…"),
    ]

    for method, host, port, targets, message in steps:
        candidates_map: dict[str, dict] = {}
        for search_target in targets:
            if progress_cb:
                progress_cb(f"{message} ({search_target})")
            for candidate in _discover_hosts(method, host, port, search_target, DISCOVERY_TIMEOUT):
                current = candidates_map.get(candidate["ip"], {})
                current.update(candidate)
                candidates_map[candidate["ip"]] = current
        candidates = list(candidates_map.values())
        verified: list[dict] = []
        total = max(len(candidates), 1)
        for idx, candidate in enumerate(candidates, start=1):
            location = candidate.get("location", "").strip()
            if not location:
                continue
            if progress_cb:
                progress_cb(f"LG TV 설명 XML 확인 중… ({idx}/{total})")
            try:
                details = _parse_device_description(_http_get_text(location))
            except Exception:
                continue
            if not details:
                continue
            ip = candidate["ip"]
            server_text = candidate.get("server", "")
            legacy_port_open = _port_open(ip, timeout=0.35)
            is_lg_tv = bool(details.get("is_lg_tv"))
            server_has_lg = "LG" in server_text.upper() or "LGSMARTTV" in server_text.upper()
            verified_flag = legacy_port_open and (is_lg_tv or server_has_lg)
            if not verified_flag:
                continue
            verified.append({
                "ip": ip,
                "verified": verified_flag,
                "label": _device_label(ip, details, True),
                "location": location,
                "server": server_text,
                "model_name": details.get("model_name", ""),
                "friendly_name": details.get("friendly_name", ""),
                "services": details.get("services", []),
            })
        if verified:
            verified.sort(key=lambda item: item["ip"])
            return verified
    return []


def request_pairing_key(ip: str) -> bool:
    """TV 화면에 PIN 표시 요청. 성공 시 True."""
    body = """<?xml version="1.0" encoding="utf-8"?>
<auth>
    <type>AuthKeyReq</type>
</auth>"""
    status, resp_text = _post_xml(ip, "auth", body)
    root = _parse_xml(resp_text)
    if root is None:
        return status == 200

    code = (
        root.findtext(".//HDCPError")
        or root.findtext(".//ROAPError")
        or root.findtext(".//result")
        or ""
    )
    return status == 200 and (not code or code == "200")


def authenticate(ip: str, code: str) -> str:
    """TV에 PIN을 제출하고 session 문자열을 반환."""
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<auth>
    <type>AuthReq</type>
    <value>{code}</value>
</auth>"""
    status, resp_text = _post_xml(ip, "auth", body)
    root = _parse_xml(resp_text)
    if status != 200 or root is None:
        raise ConnectionError("인증 응답을 해석하지 못했습니다.")

    error_code = root.findtext(".//HDCPError") or root.findtext(".//ROAPError") or ""
    if error_code and error_code != "200":
        detail = root.findtext(".//HDCPErrorDetail") or root.findtext(".//ROAPErrorDetail") or "Unknown error"
        raise PermissionError(f"인증 실패 [{error_code}]: {detail}")

    session = root.findtext(".//session", "").strip()
    if not session:
        session = root.findtext(".//value", "").strip()
    if not session:
        raw = resp_text.strip() or "(empty response)"
        raise ValueError(f"session 값을 받지 못했습니다. 응답: {raw}")
    return session


def send_key(ip: str, session: str, key_code: int) -> bool:
    """키 코드 전송. 성공 시 True."""
    body = f"""<?xml version="1.0" encoding="utf-8"?>
<command>
    <session>{session}</session>
    <type>HandleKeyInput</type>
    <value>{key_code}</value>
</command>"""
    for endpoint in ("dtv_wifirc", "command"):
        try:
            status, resp_text = _post_xml(ip, endpoint, body)
            root = _parse_xml(resp_text)
            if root is None:
                return status == 200
            code = (
                root.findtext(".//HDCPError")
                or root.findtext(".//ROAPError")
                or root.findtext(".//result")
                or ""
            )
            if status == 200 and (not code or code == "200"):
                return True
        except ConnectionError as exc:
            msg = str(exc)
            if "HTTP 404" in msg or "HTTP 400" in msg:
                continue
            return False
        except Exception:
            return False
    return False


# ──────────────────────────────────────────────
# 네트워크 스캔
# ──────────────────────────────────────────────

def _local_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


def _port_open(ip: str, timeout=0.5) -> bool:
    try:
        with socket.create_connection((ip, PORT), timeout=timeout):
            return True
    except OSError:
        return False


def scan_subnet(progress_cb=None) -> list[dict]:
    """UDAP 공식 검색으로 LG TV를 찾고, 실패 시 포트 8080 장치를 fallback으로 찾는다."""
    found = discover_lg_tvs(progress_cb=progress_cb)
    if found:
        return found

    if progress_cb:
        progress_cb("UDAP 응답이 없어 포트 8080 장치를 확인 중…")

    prefix = ".".join(_local_ip().split(".")[:3])
    candidates = [f"{prefix}.{i}" for i in range(1, 255)]
    found, done_n = [], [0]
    lock = threading.Lock()

    def check(ip):
        hit = _port_open(ip)
        with lock:
            done_n[0] += 1
            if progress_cb and (done_n[0] == 1 or done_n[0] % 25 == 0 or done_n[0] == len(candidates)):
                progress_cb(f"포트 8080 확인 중… {done_n[0]}/{len(candidates)}")
        if not hit:
            return None
        details = {"friendly_name": "", "model_name": ""}
        return {
            "ip": ip,
            "verified": False,
            "label": _device_label(ip, details, False),
        }

    with concurrent.futures.ThreadPoolExecutor(max_workers=60) as pool:
        for r in pool.map(check, candidates):
            if r:
                found.append(r)
    return found


# ──────────────────────────────────────────────
# GUI
# ──────────────────────────────────────────────

class RemoteApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("LG NetCast 리모컨")
        self.resizable(False, False)
        self.configure(bg=APP_BG)
        _apply_runtime_icon(self)
        self._control_server: socket.socket | None = None

        self._saved_state = _load_saved_state()
        self.tv_ip: str = ""
        self.session: str = ""
        self._tv_verified = False
        self._has_saved_pin = bool(str(self._saved_state.get("pin", "")).strip())
        self._scan_results: dict[str, dict] = {}

        self._build_connection_panel()
        self._build_remote_panel()

        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self._start_control_server()
        self._set_remote_enabled(False)
        self.after(150, self._startup_tv_lookup)

    # ── 연결 패널 ──────────────────────────────

    def _build_connection_panel(self):
        frm = ttk.LabelFrame(self, text="TV 연결")
        frm.grid(row=0, column=0, padx=10, pady=8, sticky="ew")
        frm.columnconfigure(3, weight=1)

        # IP 입력
        ttk.Label(frm, text="IP:").grid(row=0, column=0, padx=(10, 2), pady=6)
        self._ip_var = tk.StringVar(value=str(self._saved_state.get("tv_ip", "")).strip() or "172.30.1.82")
        ttk.Entry(frm, textvariable=self._ip_var, width=16).grid(row=0, column=1, padx=2)

        ttk.Button(frm, text="스캔", command=self._on_scan).grid(row=0, column=2, padx=4)

        # 상태 표시
        self._status_var = tk.StringVar(value="TV 확인 중 / 연결안됨")
        self._status_label = ttk.Label(frm, textvariable=self._status_var, foreground="gray")
        self._status_label.grid(row=0, column=3, columnspan=2, sticky="w", padx=(8, 10))

        # PIN 입력
        ttk.Label(frm, text="PIN:").grid(row=1, column=0, padx=(10, 2), pady=4)
        self._pin_var = tk.StringVar(value=str(self._saved_state.get("pin", "")).strip() or DEFAULT_PIN)
        ttk.Entry(frm, textvariable=self._pin_var, width=10,
                  font=("Courier", 12)).grid(row=1, column=1, padx=2)

        ttk.Button(frm, text="PIN 요청",
                   command=self._on_request_pin).grid(row=1, column=2, padx=2)
        ttk.Button(frm, text="연결",
                   command=self._on_connect).grid(row=1, column=3, padx=2)

    # ── 리모컨 패널 ────────────────────────────

    def _build_remote_panel(self):
        self._remote_wrapper, self._buttons = build_skin_remote_panel(self, self._send)
        self._remote_wrapper.grid(row=1, column=0, padx=10, pady=(0, 12))

    # ── 이벤트 핸들러 ──────────────────────────

    def _startup_tv_lookup(self):
        self._begin_ip_resolution(use_saved_ip=True)

    def _on_scan(self):
        self._begin_ip_resolution(use_saved_ip=False)

    def _begin_ip_resolution(self, use_saved_ip: bool):
        self.session = ""
        self._set_remote_enabled(False)
        self._set_status("TV 확인 중 / 연결안됨", "blue")

        def worker():
            if use_saved_ip:
                saved_ip = _load_saved_tv_ip()
                if saved_ip:
                    if _port_open(saved_ip, timeout=0.5):
                        self.after(0, lambda ip=saved_ip: self._apply_verified_ip(ip, persist=False, auto_connect=True))
                        return
                    _clear_saved_tv_ip()

            found = scan_subnet(progress_cb=None)
            self._scan_results = {item["ip"]: item for item in found}
            if found:
                verified = [item for item in found if item.get("verified")]
                chosen = verified[0] if verified else found[0]
                if chosen.get("verified"):
                    self.after(0, lambda ip=chosen["ip"]: self._apply_verified_ip(ip, persist=True, auto_connect=True))
                else:
                    self.after(0, lambda ip=chosen["ip"]: self._apply_candidate_ip(ip))
            else:
                self.after(0, self._apply_no_tv_found)

        threading.Thread(target=worker, daemon=True).start()

    def _on_request_pin(self):
        ip = self._ip_var.get().strip()
        if not ip:
            messagebox.showwarning("오류", "IP를 입력하세요.")
            return
        self._set_status("TV 확인 중 / 연결안됨", "blue")

        def worker():
            try:
                ok = request_pairing_key(ip)
                if ok:
                    self.after(0, lambda ip=ip: self._apply_verified_ip(ip, persist=True, note="PIN 표시됨"))
                else:
                    self.after(0, lambda: self._show_connection_state(False, note="PIN 요청 실패", color="red"))
            except Exception as e:
                self.after(0, lambda e=e: self._show_connection_state(False, note=f"PIN 요청 실패: {e}", color="red"))

        threading.Thread(target=worker, daemon=True).start()

    def _on_connect(self):
        ip  = self._ip_var.get().strip()
        pin = self._pin_var.get().strip()
        if not ip or not pin:
            messagebox.showwarning("오류", "IP와 PIN을 입력하세요.")
            return
        self._start_connect(ip, pin, auto=False)

    def _start_connect(self, ip: str, pin: str, auto: bool):
        self.session = ""
        self._set_remote_enabled(False)
        self._set_status("연결 확인 중…", "blue")
        _save_pin(pin)
        self._has_saved_pin = True

        def worker():
            try:
                session = authenticate(ip, pin)
                self.tv_ip = ip
                self.session = session
                self.after(0, lambda: self._on_connected())
            except Exception as e:
                self.session = ""
                note = f"연결안됨: {e}" if not auto else "연결안됨"
                self.after(0, lambda note=note: self._show_connection_state(False, note=note, color="red"))

        threading.Thread(target=worker, daemon=True).start()

    def _maybe_auto_connect(self):
        ip = self._ip_var.get().strip()
        pin = self._pin_var.get().strip()
        if self._tv_verified and ip and pin and self._has_saved_pin:
            self._start_connect(ip, pin, auto=True)

    def _on_connected(self):
        self._tv_verified = True
        _save_tv_ip(self.tv_ip)
        _save_pin(self._pin_var.get().strip())
        self._show_connection_state(True)
        self.title(f"LG 리모컨 — {self.tv_ip}")
        self._set_remote_enabled(True)

    # ── 키 전송 ────────────────────────────────

    def _send(self, code: int):
        if not self.session:
            messagebox.showwarning("미연결", "먼저 TV에 연결하세요.")
            return

        def worker():
            ok = send_key(self.tv_ip, self.session, code)
            if not ok:
                self.after(0, lambda: self._show_connection_state(True, note=f"키 전송 실패 ({code})", color="red"))

        threading.Thread(target=worker, daemon=True).start()

    # ── 유틸 ───────────────────────────────────

    def _apply_verified_ip(self, ip: str, persist: bool, note: str = "", auto_connect: bool = False):
        self._ip_var.set(ip)
        self.tv_ip = ""
        self.session = ""
        self._tv_verified = True
        if persist:
            _save_tv_ip(ip)
        self._set_remote_enabled(False)
        self._show_connection_state(False, note=note)
        if auto_connect:
            self.after(50, self._maybe_auto_connect)

    def _apply_candidate_ip(self, ip: str):
        self._ip_var.set(ip)
        self.tv_ip = ""
        self.session = ""
        self._tv_verified = False
        self._set_remote_enabled(False)
        self._show_connection_state(False)

    def _apply_no_tv_found(self):
        self.tv_ip = ""
        self.session = ""
        self._tv_verified = False
        self._set_remote_enabled(False)
        self._show_connection_state(False)

    def _show_connection_state(self, connected: bool, note: str = "", color: str | None = None):
        detected = "TV 확인됨" if self._tv_verified else "TV 미확인"
        state = "연결됨" if connected else "연결안됨"
        message = f"{detected} / {state}"
        if note:
            message = f"{message} / {note}"
        if color is None:
            if connected:
                color = "darkgreen"
            elif detected == "TV 확인됨":
                color = "green"
            else:
                color = "orange"
        self._set_status(message, color)

    def _set_status(self, msg: str, color: str = "gray"):
        self._status_var.set(msg)
        try:
            self._status_label.config(foreground=color)
        except Exception:
            pass

    def _set_remote_enabled(self, enabled: bool):
        for b in self._buttons:
            try:
                if hasattr(b, "set_enabled"):
                    b.set_enabled(enabled)
                else:
                    b.config(cursor="hand2" if enabled else "arrow")
            except Exception:
                pass

    def _start_control_server(self):
        try:
            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server.bind(("127.0.0.1", WINDOW_CONTROL_PORT))
            server.listen(1)
        except OSError:
            return

        self._control_server = server

        def worker():
            while self._control_server:
                try:
                    conn, _ = server.accept()
                except OSError:
                    break
                with conn:
                    try:
                        payload = conn.recv(32).decode("utf-8", errors="ignore").strip().upper()
                    except OSError:
                        payload = ""
                    if payload.startswith("SHOW"):
                        self.after(0, self._raise_window)

        threading.Thread(target=worker, daemon=True).start()

    def _raise_window(self):
        try:
            self.deiconify()
            self.lift()
            self.attributes("-topmost", True)
            self.after(200, lambda: self.attributes("-topmost", False))
            self.focus_force()
        except Exception:
            pass

    def _on_close(self):
        if self._control_server:
            try:
                self._control_server.close()
            except OSError:
                pass
            self._control_server = None
        self.destroy()


def _load_menu_target() -> tuple[str, str]:
    ip = _load_saved_tv_ip().strip()
    pin = _load_saved_pin().strip() or DEFAULT_PIN
    if not ip:
        raise ValueError("저장된 TV IP가 없습니다.\n리모콘패널에서 먼저 연결해주세요.")
    return ip, pin


def run_remote_window():
    if _notify_existing_window():
        return
    app = RemoteApp()
    app.mainloop()


def run_menubar_app():
    try:
        import rumps
    except Exception as exc:
        raise RuntimeError("메뉴바 모드를 실행하려면 rumps와 pyobjc가 필요합니다.") from exc

    class MenuBarApp(rumps.App):
        def __init__(self):
            icon_path = _resource_path("assets", "lg_menu_icon.png")
            super().__init__(
                name="LG 전자 리모콘",
                title="",
                icon=icon_path if Path(icon_path).exists() else None,
                quit_button="종료",
            )
            self.tv_ip = ""
            self.pin = DEFAULT_PIN
            self.session = ""

            self.login_item = rumps.MenuItem("로그인시시작", callback=self.toggle_login_item)
            self.login_item.state = 1 if _login_item_enabled() else 0

            self.menu = [
                rumps.MenuItem("MUTE", callback=self._make_send_callback("MUTE", "MUTE")),
                rumps.MenuItem("VOL+", callback=self._make_send_callback("VOL+", "VOL+")),
                rumps.MenuItem("VOL-", callback=self._make_send_callback("VOL-", "VOL-")),
                rumps.MenuItem("CH+", callback=self._make_send_callback("CH+", "CH+")),
                rumps.MenuItem("CH-", callback=self._make_send_callback("CH-", "CH-")),
                rumps.MenuItem("리모콘패널", callback=self.open_remote_panel),
                None,
                self.login_item,
                None,
                rumps.MenuItem("이프로그램은?", callback=self.show_about),
            ]

        def _run_async(self, fn):
            threading.Thread(target=fn, daemon=True).start()

        def _refresh_target(self):
            ip, pin = _load_menu_target()
            if ip != self.tv_ip or pin != self.pin:
                self.session = ""
            self.tv_ip = ip
            self.pin = pin
            return ip, pin

        def _ensure_session(self):
            ip, pin = self._refresh_target()
            if not self.session:
                self.session = authenticate(ip, pin)
            return ip, self.session

        def _make_send_callback(self, key_name: str, label: str):
            def callback(_):
                self._run_async(lambda: self._send_key_action(key_name, label))
            return callback

        def _send_key_action(self, key_name: str, label: str):
            try:
                ip, session = self._ensure_session()
                key_code = KEY_CODE[key_name]
                ok = send_key(ip, session, key_code)
                if ok:
                    return
                self.session = ""
                ip, session = self._ensure_session()
                ok = send_key(ip, session, key_code)
                if not ok:
                    raise RuntimeError("키 전송에 실패했습니다.")
            except Exception as exc:
                self.session = ""
                rumps.alert(title=label, message=str(exc))

        def open_remote_panel(self, _):
            if _notify_existing_window():
                return
            try:
                subprocess.Popen(
                    _current_launch_command(window_mode=True),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except Exception as exc:
                rumps.alert(title="리모콘패널", message=f"창을 열지 못했습니다.\n{exc}")

        def toggle_login_item(self, sender):
            try:
                if sender.state:
                    remove_login_item()
                    sender.state = 0
                    rumps.notification("LG 전자 리모콘", "로그인시시작", "자동 시작을 해제했습니다.")
                else:
                    install_login_item()
                    sender.state = 1
                    rumps.notification("LG 전자 리모콘", "로그인시시작", "자동 시작을 등록했습니다.")
            except Exception as exc:
                sender.state = 1 if _login_item_enabled() else 0
                rumps.alert(title="로그인시시작", message=str(exc))

        def show_about(self, _):
            rumps.alert(
                title="이프로그램은?",
                message="LG 전자 리모콘이고\n이상목이 만들었습니다.",
            )

    _configure_macos_accessory_mode()
    MenuBarApp().run()


# ──────────────────────────────────────────────
# 진입점
# ──────────────────────────────────────────────

def main(argv: list[str] | None = None):
    parser = argparse.ArgumentParser(description="LG NetCast 2st remote / menubar app")
    parser.add_argument("--window", action="store_true", help="run the Tk remote window directly")
    parser.add_argument("--install-login-item", action="store_true", help="install the LaunchAgent")
    parser.add_argument("--remove-login-item", action="store_true", help="remove the LaunchAgent")
    args = parser.parse_args(argv)

    if args.install_login_item:
        print(install_login_item())
        return
    if args.remove_login_item:
        print(remove_login_item())
        return
    if args.window:
        run_remote_window()
        return
    run_menubar_app()


if __name__ == "__main__":
    main()
