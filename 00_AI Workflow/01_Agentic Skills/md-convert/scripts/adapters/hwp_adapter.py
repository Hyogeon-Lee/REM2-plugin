"""HWP 5.x → Markdown 변환 어댑터 (텍스트만, best-effort).

전략 (옵션 B):
- olefile로 OLE2 컨테이너 열기
- BodyText/Section* 스트림에서 레코드 파싱 → 문단 텍스트 추출
- 압축된 경우 zlib(-15) 으로 raw deflate 풀기
- 이미지/표는 미지원 (해당 시 안내 메시지 + HWPX 변환 권장)

라이선스: MIT (olefile)
한계: 표 구조, 이미지 추출 불가. 텍스트만 best-effort.
"""
from __future__ import annotations

import re
import struct
import zlib
from pathlib import Path

import olefile


# HWP5 레코드 태그 ID
HWPTAG_BEGIN = 0x10
HWPTAG_PARA_HEADER = HWPTAG_BEGIN + 50  # 0x42
HWPTAG_PARA_TEXT = HWPTAG_BEGIN + 51    # 0x43
HWPTAG_PARA_CHAR_SHAPE = HWPTAG_BEGIN + 52
HWPTAG_PARA_LINE_SEG = HWPTAG_BEGIN + 53


def convert(input_path: Path, output_md_path: Path) -> dict:
    md_lines: list[str] = [f"# {output_md_path.stem}"]
    warnings: list[str] = [
        "HWP 5.x는 텍스트 추출만 지원합니다. 이미지/표 보존이 필요하면 한컴오피스에서 HWPX로 저장 후 다시 변환하세요."
    ]

    if not olefile.isOleFile(str(input_path)):
        raise ValueError(f"올바른 HWP 파일이 아님: {input_path}")

    ole = olefile.OleFileIO(str(input_path))
    try:
        # FileHeader에서 압축 여부 확인
        compressed = _is_compressed(ole)

        # BodyText/Section0, Section1, ... 순회
        section_streams = _list_section_streams(ole)
        if not section_streams:
            warnings.append("BodyText 섹션을 찾지 못함")

        for stream_path in section_streams:
            try:
                raw = ole.openstream(stream_path).read()
                if compressed:
                    raw = zlib.decompress(raw, -15)
                texts = _parse_section_records(raw)
                for line in texts:
                    if line.strip():
                        md_lines.append(line)
            except Exception as e:
                warnings.append(f"섹션 {stream_path} 파싱 실패: {e}")
    finally:
        ole.close()

    output_md_path.write_text("\n\n".join(md_lines) + "\n", encoding="utf-8")
    return {"image_count": 0, "warnings": warnings}


def _is_compressed(ole) -> bool:
    """FileHeader 스트림에서 압축 플래그 확인."""
    try:
        header = ole.openstream("FileHeader").read()
        # 36바이트 시그니처 + 4바이트 버전 + 4바이트 속성(플래그)
        if len(header) >= 44:
            flags = struct.unpack("<I", header[36:40])[0]
            return bool(flags & 0x1)
    except Exception:
        pass
    return False


def _list_section_streams(ole) -> list[list[str]]:
    """BodyText/Section* 스트림 경로 목록을 정렬해서 반환."""
    sections = []
    for entry in ole.listdir():
        if (
            len(entry) >= 2
            and entry[0] == "BodyText"
            and entry[1].lower().startswith("section")
        ):
            sections.append(entry)
    # numeric sort: Section10이 Section2보다 뒤에 오도록
    sections.sort(key=lambda e: int(m.group()) if (m := re.search(r"\d+", e[1])) else 0)
    return sections


def _parse_section_records(data: bytes) -> list[str]:
    """섹션 raw 바이트에서 PARA_TEXT 레코드들을 뽑아 텍스트로."""
    paragraphs: list[str] = []
    current: list[str] = []
    pos = 0
    n = len(data)

    while pos + 4 <= n:
        header = struct.unpack("<I", data[pos : pos + 4])[0]
        tag_id = header & 0x3FF
        # level = (header >> 10) & 0x3FF  # 사용 안 함
        size = (header >> 20) & 0xFFF
        pos += 4
        if size == 0xFFF:
            # 확장 크기: 다음 4바이트가 실제 크기
            if pos + 4 > n:
                break
            size = struct.unpack("<I", data[pos : pos + 4])[0]
            pos += 4

        if pos + size > n:
            break
        body = data[pos : pos + size]
        pos += size

        if tag_id == HWPTAG_PARA_HEADER:
            # 새 문단 시작 → 이전 문단 flush
            if current:
                paragraphs.append("".join(current))
                current = []
        elif tag_id == HWPTAG_PARA_TEXT:
            text = _decode_para_text(body)
            if text:
                current.append(text)

    if current:
        paragraphs.append("".join(current))

    return paragraphs


def _decode_para_text(body: bytes) -> str:
    """PARA_TEXT 레코드 본문을 UTF-16LE로 디코딩하면서 컨트롤 문자 처리.

    HWP5 컨트롤 문자(0~31 중 일부)는 inline 객체(이미지/표 등)나 줄바꿈을 의미.
    여기서는 텍스트만 추출하므로 컨트롤 문자는 적절히 변환.
    """
    out: list[str] = []
    pos = 0
    n = len(body)
    while pos + 2 <= n:
        ch = struct.unpack("<H", body[pos : pos + 2])[0]
        pos += 2
        if ch < 32:
            # inline 컨트롤 - 17바이트 짜리(앞뒤 같은 코드 포함)와 일반 컨트롤 구분
            if ch in (0, 10, 13):
                # null, line feed, carriage return
                if ch in (10, 13):
                    out.append("\n")
            elif ch in (1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23):
                # extended control: 14 bytes 추가 데이터 + 종료 코드 2바이트 = 총 16바이트 추가
                # 각 컨트롤마다 다름. HWP5 스펙의 "inline control 14 bytes, extended control"
                # 단순화: 12 bytes(6 wchar) skip + 종료 코드 검증
                # 실제로는 컨트롤마다 페이로드 길이가 다르지만 most common 14-byte 패턴 가정
                pos += 14
                # 종료 컨트롤 코드 (같은 ch가 한 번 더)
                if pos + 2 <= n:
                    end = struct.unpack("<H", body[pos : pos + 2])[0]
                    if end == ch:
                        pos += 2
                # 의미 단절 표시
                out.append(" ")
            elif ch == 24:
                # hyphen
                out.append("-")
            elif ch == 30:
                # non-breaking space
                out.append("\u00A0")
            elif ch == 31:
                # fixed-width space
                out.append(" ")
            # 나머지는 무시
        else:
            out.append(chr(ch))

    return "".join(out)
