import os
import hashlib
from typing import List, Optional
from mutagen.mp3 import MP3
from app.models.schemas import Song
from app.core.config import settings


def _song_id(path: str) -> str:
    return hashlib.md5(path.encode()).hexdigest()[:12]


def _parse_filename(filename: str) -> tuple[str, str]:
    """Tenta extrair artista e título do nome do arquivo.
    Formatos comuns: 'Artista - Título.mp3' ou 'Título.mp3'
    """
    name = os.path.splitext(filename)[0]
    if " - " in name:
        parts = name.split(" - ", 1)
        return parts[0].strip(), parts[1].strip()
    return "Desconhecido", name.strip()


def scan_library() -> List[Song]:
    songs = []
    media_path = settings.media_path

    if not os.path.exists(media_path):
        return songs

    for root, _, files in os.walk(media_path):
        mp3_files = {f.lower() for f in files if f.lower().endswith(".mp3")}
        cdg_files = {f.lower() for f in files if f.lower().endswith(".cdg")}

        for f in files:
            if not f.lower().endswith(".mp3"):
                continue

            mp3_path = os.path.join(root, f)
            cdg_name = os.path.splitext(f)[0] + ".cdg"
            has_cdg = cdg_name.lower() in cdg_files

            artist, title = _parse_filename(f)

            duration = None
            try:
                audio = MP3(mp3_path)
                duration = int(audio.info.length)
            except Exception:
                pass

            songs.append(Song(
                id=_song_id(mp3_path),
                title=title,
                artist=artist,
                duration_seconds=duration,
                has_cdg=has_cdg,
            ))

    return sorted(songs, key=lambda s: (s.artist.lower(), s.title.lower()))


def get_song_path(song_id: str) -> Optional[str]:
    for root, _, files in os.walk(settings.media_path):
        for f in files:
            if not f.lower().endswith(".mp3"):
                continue
            path = os.path.join(root, f)
            if _song_id(path) == song_id:
                return path
    return None


def get_cdg_path(song_id: str) -> Optional[str]:
    mp3_path = get_song_path(song_id)
    if not mp3_path:
        return None
    cdg_path = os.path.splitext(mp3_path)[0] + ".cdg"
    return cdg_path if os.path.exists(cdg_path) else None
