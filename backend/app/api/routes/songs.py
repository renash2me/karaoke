from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse
from typing import List, Optional
from app.models.schemas import Song
from app.services.library import scan_library, get_song_path, get_cdg_path
from app.core.auth import get_current_admin

router = APIRouter(prefix="/api/songs", tags=["songs"])

_cache: Optional[List[Song]] = None


def get_library() -> List[Song]:
    global _cache
    if _cache is None:
        _cache = scan_library()
    return _cache


@router.get("/", response_model=List[Song])
async def list_songs(q: Optional[str] = None):
    songs = get_library()
    if q:
        q_lower = q.lower()
        songs = [s for s in songs if q_lower in s.title.lower() or q_lower in s.artist.lower()]
    return songs


@router.post("/rescan", dependencies=[Depends(get_current_admin)])
async def rescan():
    global _cache
    _cache = None
    songs = get_library()
    return {"total": len(songs)}


@router.get("/{song_id}/audio")
async def stream_audio(song_id: str):
    path = get_song_path(song_id)
    if not path:
        raise HTTPException(status_code=404, detail="Música não encontrada")
    return FileResponse(path, media_type="audio/mpeg")


@router.get("/{song_id}/cdg")
async def stream_cdg(song_id: str):
    path = get_cdg_path(song_id)
    if not path:
        raise HTTPException(status_code=404, detail="CDG não encontrado")
    return FileResponse(path, media_type="application/octet-stream")
