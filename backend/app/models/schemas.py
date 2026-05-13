from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class Song(BaseModel):
    id: str
    title: str
    artist: str
    duration_seconds: Optional[int] = None
    has_cdg: bool = True


class Room(BaseModel):
    id: str
    name: str
    code: str
    created_at: datetime
    is_active: bool = True


class QueueItem(BaseModel):
    id: str
    room_id: str
    song_id: str
    singer_name: str
    added_at: datetime
    status: str = "waiting"  # waiting, singing, done


class ScoreEntry(BaseModel):
    room_id: str
    singer_name: str
    song_id: str
    score: int
    accuracy: float
    sung_at: datetime


class ScoreUpdate(BaseModel):
    singer_name: str
    score: int
    accuracy: float
    pitch_data: Optional[list] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
