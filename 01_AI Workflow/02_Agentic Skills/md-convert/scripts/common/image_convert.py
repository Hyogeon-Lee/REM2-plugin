"""이미지 포맷을 PNG로 통일 변환.

지원:
- WMF/EMF (벡터): Windows GDI로 래스터화 (ctypes — Windows 전용, stdlib)
- BMP/JPEG/GIF/TIFF/WEBP/etc (래스터): Pillow로 PNG 재인코딩
- PNG: 그대로 통과 (재인코딩 없음)

10MB 안전장치: pixel × 1.5 bytes 추정. 초과 시 sqrt 스케일링.
물리 크기 결정: 벡터 헤더 → 호출자 힌트 → A4 fallback.
"""
from __future__ import annotations

import io
import math
import struct
from typing import Optional


A4_MM = (210.0, 297.0)
DEFAULT_DPI = 400
MIN_DPI = 150
MAX_BYTES = 10 * 1024 * 1024
RASTER_BYTES_PER_PIXEL = 1.5  # PNG 추정 (선화 기준 보수적)


def to_png(
    data: bytes,
    physical_size_mm: Optional[tuple[float, float]] = None,
    target_dpi: int = DEFAULT_DPI,
    max_bytes: int = MAX_BYTES,
    min_dpi: int = MIN_DPI,
) -> tuple[bytes, list[str]]:
    """이미지 바이트를 PNG로 변환.

    Returns:
        (png_bytes, warnings).
        변환 실패 시 (원본 데이터, [warning]) — 절대 raise 안함.
    """
    warnings: list[str] = []
    if not data:
        return data, ["빈 이미지 데이터"]

    # PNG: 한도 이하면 그대로 통과, 초과 시 Pillow로 다운샘플
    if _is_png(data):
        if len(data) <= max_bytes:
            return data, warnings
        return _raster_to_png(data, max_bytes, warnings)

    fmt = _detect_vector(data)
    if fmt is not None:
        return _vectorize_to_png(
            data, fmt, physical_size_mm, target_dpi, max_bytes, min_dpi, warnings
        )

    return _raster_to_png(data, max_bytes, warnings)


# ---------- 포맷 감지 ----------

def _is_png(data: bytes) -> bool:
    return len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n"


def _detect_vector(data: bytes) -> Optional[str]:
    """'wmf_placeable' | 'wmf_raw' | 'emf' | None."""
    if len(data) < 4:
        return None
    if data[:4] == b"\xd7\xcd\xc6\x9a":
        return "wmf_placeable"
    if data[:4] in (b"\x01\x00\x09\x00", b"\x02\x00\x09\x00"):
        return "wmf_raw"
    # EMF: type 1 + " EMF" 시그니처 둘 다 필요 (false positive 방지)
    if (
        len(data) >= 44
        and data[:4] == b"\x01\x00\x00\x00"
        and data[40:44] == b" EMF"
    ):
        return "emf"
    return None


# ---------- 물리 크기 파싱 ----------

def _parse_placeable_wmf_frame_mm(data: bytes) -> Optional[tuple[float, float]]:
    """Placeable WMF 22-byte 헤더에서 frame 크기 (mm)."""
    if len(data) < 22:
        return None
    try:
        left, top, right, bottom = struct.unpack("<hhhh", data[6:14])
        inch = struct.unpack("<H", data[14:16])[0]
        if inch == 0:
            return None
        w_in = (right - left) / inch
        h_in = (bottom - top) / inch
        if w_in <= 0 or h_in <= 0:
            return None
        return (w_in * 25.4, h_in * 25.4)
    except struct.error:
        return None


def _parse_emf_frame_mm(data: bytes) -> Optional[tuple[float, float]]:
    """EMR_HEADER의 rclFrame (0.01mm 단위) → mm."""
    if len(data) < 40:
        return None
    try:
        l, t, r, b = struct.unpack("<iiii", data[24:40])
        w_mm = (r - l) / 100.0
        h_mm = (b - t) / 100.0
        if w_mm <= 0 or h_mm <= 0:
            return None
        return (w_mm, h_mm)
    except struct.error:
        return None


def _resolve_size_mm(
    fmt: str, data: bytes, hint: Optional[tuple[float, float]]
) -> tuple[tuple[float, float], str]:
    """벡터 물리 크기 결정: 헤더 → 힌트 → A4."""
    if fmt == "emf":
        size = _parse_emf_frame_mm(data)
        if size:
            return size, "emf_header"
    elif fmt in ("wmf_placeable",):
        size = _parse_placeable_wmf_frame_mm(data)
        if size:
            return size, "wmf_placeable_header"
    if hint and hint[0] > 0 and hint[1] > 0:
        return hint, "caller_hint"
    return A4_MM, "a4_fallback"


# ---------- DPI 계산 ----------

def _compute_dpi(
    size_mm: tuple[float, float],
    target_dpi: int,
    max_bytes: int,
    min_dpi: int,
) -> tuple[int, list[str]]:
    """10MB 한도에 맞춰 sqrt 스케일링."""
    warnings: list[str] = []
    w_mm, h_mm = size_mm
    w_in = w_mm / 25.4
    h_in = h_mm / 25.4

    pixels = (w_in * target_dpi) * (h_in * target_dpi)
    estimated_bytes = pixels * RASTER_BYTES_PER_PIXEL

    if estimated_bytes <= max_bytes:
        return target_dpi, warnings

    scale = math.sqrt(max_bytes / estimated_bytes)
    new_dpi = max(min_dpi, int(target_dpi * scale))

    if new_dpi == min_dpi:
        new_pixels = (w_in * new_dpi) * (h_in * new_dpi)
        if new_pixels * RASTER_BYTES_PER_PIXEL > max_bytes:
            warnings.append(
                f"이미지 추정 {new_pixels * RASTER_BYTES_PER_PIXEL / 1024 / 1024:.1f}MB가 "
                f"한도 {max_bytes // 1024 // 1024}MB 초과 — 최소 DPI {min_dpi} 적용"
            )
    else:
        warnings.append(
            f"DPI {target_dpi} → {new_dpi} 다운스케일 (10MB 한도)"
        )
    return new_dpi, warnings


# ---------- 벡터 → PNG ----------

def _vectorize_to_png(
    data: bytes,
    fmt: str,
    hint: Optional[tuple[float, float]],
    target_dpi: int,
    max_bytes: int,
    min_dpi: int,
    warnings: list[str],
) -> tuple[bytes, list[str]]:
    size_mm, _src = _resolve_size_mm(fmt, data, hint)
    dpi, dpi_warns = _compute_dpi(size_mm, target_dpi, max_bytes, min_dpi)
    warnings.extend(dpi_warns)

    try:
        png_bytes = _rasterize_metafile_gdi(data, fmt, size_mm, dpi)
    except (ImportError, OSError) as e:
        warnings.append(
            f"GDI 사용 불가 ({type(e).__name__}: {e}) — {fmt} 원본 그대로 저장"
        )
        return data, warnings
    except Exception as e:
        warnings.append(f"벡터 래스터화 실패 ({fmt}): {e} — 원본 그대로 저장")
        return data, warnings

    # 검은 이미지 감지
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(png_bytes))
        ext = img.getextrema()
        channels = ext if isinstance(ext, list) else [ext]
        if all(isinstance(c, tuple) and c[0] == 0 and c[1] == 0 for c in channels):
            warnings.append(
                "래스터화 결과가 전부 검은색 — 폰트/렌더러 누락 가능성"
            )
    except Exception:
        pass

    return png_bytes, warnings


def _rasterize_metafile_gdi(
    data: bytes,
    fmt: str,
    size_mm: tuple[float, float],
    dpi: int,
) -> bytes:
    """ctypes로 Windows GDI 호출 → PNG bytes. Windows 전용."""
    import ctypes
    from ctypes import wintypes

    if not hasattr(ctypes, "windll"):
        raise ImportError("ctypes.windll 미지원 (비-Windows)")

    from PIL import Image

    gdi32 = ctypes.windll.gdi32
    user32 = ctypes.windll.user32

    # 함수 시그니처 등록
    gdi32.SetEnhMetaFileBits.argtypes = [wintypes.UINT, ctypes.c_char_p]
    gdi32.SetEnhMetaFileBits.restype = wintypes.HANDLE
    gdi32.SetWinMetaFileBits.argtypes = [
        wintypes.UINT, ctypes.c_char_p, wintypes.HDC, ctypes.c_void_p
    ]
    gdi32.SetWinMetaFileBits.restype = wintypes.HANDLE
    gdi32.DeleteEnhMetaFile.argtypes = [wintypes.HANDLE]
    gdi32.DeleteEnhMetaFile.restype = wintypes.BOOL
    gdi32.PlayEnhMetaFile.argtypes = [
        wintypes.HDC, wintypes.HANDLE, ctypes.POINTER(wintypes.RECT)
    ]
    gdi32.PlayEnhMetaFile.restype = wintypes.BOOL
    gdi32.CreateCompatibleDC.argtypes = [wintypes.HDC]
    gdi32.CreateCompatibleDC.restype = wintypes.HDC
    gdi32.CreateCompatibleBitmap.argtypes = [
        wintypes.HDC, ctypes.c_int, ctypes.c_int
    ]
    gdi32.CreateCompatibleBitmap.restype = wintypes.HBITMAP
    gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
    gdi32.SelectObject.restype = wintypes.HGDIOBJ
    gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
    gdi32.DeleteObject.restype = wintypes.BOOL
    gdi32.DeleteDC.argtypes = [wintypes.HDC]
    gdi32.DeleteDC.restype = wintypes.BOOL
    gdi32.GetStockObject.argtypes = [ctypes.c_int]
    gdi32.GetStockObject.restype = wintypes.HGDIOBJ

    user32.FillRect.argtypes = [
        wintypes.HDC, ctypes.POINTER(wintypes.RECT), wintypes.HBRUSH
    ]
    user32.FillRect.restype = ctypes.c_int
    user32.GetDC.argtypes = [wintypes.HWND]
    user32.GetDC.restype = wintypes.HDC
    user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
    user32.ReleaseDC.restype = ctypes.c_int

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [
            ("biSize", wintypes.DWORD),
            ("biWidth", wintypes.LONG),
            ("biHeight", wintypes.LONG),
            ("biPlanes", wintypes.WORD),
            ("biBitCount", wintypes.WORD),
            ("biCompression", wintypes.DWORD),
            ("biSizeImage", wintypes.DWORD),
            ("biXPelsPerMeter", wintypes.LONG),
            ("biYPelsPerMeter", wintypes.LONG),
            ("biClrUsed", wintypes.DWORD),
            ("biClrImportant", wintypes.DWORD),
        ]

    gdi32.GetDIBits.argtypes = [
        wintypes.HDC, wintypes.HBITMAP, wintypes.UINT, wintypes.UINT,
        ctypes.c_void_p, ctypes.POINTER(BITMAPINFOHEADER), wintypes.UINT,
    ]
    gdi32.GetDIBits.restype = ctypes.c_int

    WHITE_BRUSH = 0
    DIB_RGB_COLORS = 0
    BI_RGB = 0

    w_mm, h_mm = size_mm
    width_px = max(1, int(round(w_mm / 25.4 * dpi)))
    height_px = max(1, int(round(h_mm / 25.4 * dpi)))

    # WMF/EMF → HENHMETAFILE
    if fmt == "emf":
        hemf = gdi32.SetEnhMetaFileBits(len(data), data)
    else:
        wmf_bits = data[22:] if fmt == "wmf_placeable" else data
        hemf = gdi32.SetWinMetaFileBits(
            len(wmf_bits), wmf_bits, wintypes.HDC(0), None
        )

    if not hemf:
        raise RuntimeError(f"{fmt} → HENHMETAFILE 변환 실패")

    try:
        screen_dc = user32.GetDC(None)
        if not screen_dc:
            raise RuntimeError("GetDC 실패")
        try:
            mem_dc = gdi32.CreateCompatibleDC(screen_dc)
            if not mem_dc:
                raise RuntimeError("CreateCompatibleDC 실패")
            bitmap = gdi32.CreateCompatibleBitmap(screen_dc, width_px, height_px)
            if not bitmap:
                gdi32.DeleteDC(mem_dc)
                raise RuntimeError("CreateCompatibleBitmap 실패")

            old_obj = gdi32.SelectObject(mem_dc, bitmap)
            try:
                rect = wintypes.RECT(0, 0, width_px, height_px)
                white_brush = gdi32.GetStockObject(WHITE_BRUSH)
                user32.FillRect(mem_dc, ctypes.byref(rect), white_brush)

                ok = gdi32.PlayEnhMetaFile(mem_dc, hemf, ctypes.byref(rect))
                if not ok:
                    raise RuntimeError("PlayEnhMetaFile 실패")

                bi = BITMAPINFOHEADER()
                bi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
                bi.biWidth = width_px
                bi.biHeight = -height_px  # top-down DIB
                bi.biPlanes = 1
                bi.biBitCount = 32
                bi.biCompression = BI_RGB

                buf_size = width_px * height_px * 4
                buf = (ctypes.c_ubyte * buf_size)()

                lines = gdi32.GetDIBits(
                    mem_dc, bitmap, 0, height_px, buf,
                    ctypes.byref(bi), DIB_RGB_COLORS
                )
                if lines == 0:
                    raise RuntimeError("GetDIBits 실패")

                img = Image.frombuffer(
                    "RGB", (width_px, height_px), bytes(buf),
                    "raw", "BGRX", 0, 1
                )
                out_buf = io.BytesIO()
                img.save(out_buf, format="PNG", optimize=True)
                return out_buf.getvalue()
            finally:
                gdi32.SelectObject(mem_dc, old_obj)
                gdi32.DeleteObject(bitmap)
                gdi32.DeleteDC(mem_dc)
        finally:
            user32.ReleaseDC(None, screen_dc)
    finally:
        gdi32.DeleteEnhMetaFile(hemf)


# ---------- 래스터 → PNG ----------

def _raster_to_png(
    data: bytes, max_bytes: int, warnings: list[str]
) -> tuple[bytes, list[str]]:
    """Pillow로 PNG 재인코딩. 픽셀 예산 초과 시 LANCZOS 다운샘플."""
    try:
        from PIL import Image
    except ImportError:
        warnings.append("Pillow 미설치 — 이미지 원본 그대로 저장")
        return data, warnings

    try:
        img = Image.open(io.BytesIO(data))
        img.load()
    except Exception as e:
        warnings.append(f"이미지 디코딩 실패: {e} — 원본 그대로 저장")
        return data, warnings

    # PNG 호환 모드로 정규화
    if img.mode not in ("RGB", "RGBA", "L", "LA", "P", "1"):
        img = img.convert("RGBA" if "A" in img.mode else "RGB")

    w, h = img.size
    pixels = w * h
    target_pixels = max_bytes / RASTER_BYTES_PER_PIXEL

    if pixels > target_pixels:
        scale = math.sqrt(target_pixels / pixels)
        new_w = max(1, int(w * scale))
        new_h = max(1, int(h * scale))
        warnings.append(
            f"이미지 {w}×{h} → {new_w}×{new_h} 다운샘플 (10MB 한도)"
        )
        img = img.resize((new_w, new_h), Image.LANCZOS)

    out_buf = io.BytesIO()
    img.save(out_buf, format="PNG", optimize=True)
    return out_buf.getvalue(), warnings
