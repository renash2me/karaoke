import re
import httpx
from typing import Optional

LRCLIB_URL = "https://lrclib.net/api/get"


async def fetch_lyrics(artist: str, title: str) -> Optional[str]:
    """Busca letra sincronizada (LRC) na LRCLIB."""
    # Limpa códigos de disco do artista (ex: SF337-01 -> busca pelo título)
    clean_artist = artist if not re.match(r'^SF\d+', artist) else ""
    
    # Tenta extrair artista do título se vier no formato "Artista - Título"
    if " - " in title and not clean_artist:
        parts = title.split(" - ", 1)
        clean_artist = parts[0].strip()
        clean_title = parts[1].strip()
    else:
        clean_title = title

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            params = {"artist_name": clean_artist, "track_name": clean_title}
            r = await client.get(LRCLIB_URL, params=params)
            if r.status_code == 200:
                data = r.json()
                return data.get("syncedLyrics") or data.get("plainLyrics")
    except Exception:
        pass
    return None


def parse_lrc(lrc: str) -> list[dict]:
    """Converte LRC em lista de {time_ms, text}."""
    lines = []
    pattern = re.compile(r'\[(\d+):(\d+\.\d+)\](.*)')
    for line in lrc.splitlines():
        m = pattern.match(line.strip())
        if m:
            minutes = int(m.group(1))
            seconds = float(m.group(2))
            text = m.group(3).strip()
            time_ms = int((minutes * 60 + seconds) * 1000)
            lines.append({"time_ms": time_ms, "text": text})
    return sorted(lines, key=lambda x: x["time_ms"])
