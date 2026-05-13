import uuid
import random
import string
from datetime import datetime
from typing import List, Optional, Dict
from app.models.schemas import Room, QueueItem, ScoreEntry


# Storage em memória (simples para fase 1 — persiste enquanto o container rodar)
_rooms: Dict[str, Room] = {}
_queues: Dict[str, List[QueueItem]] = {}  # room_id -> lista
_scores: Dict[str, List[ScoreEntry]] = {}  # room_id -> lista


def _random_code(length=6) -> str:
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))


# --- Salas ---

def create_room(name: str) -> Room:
    room = Room(
        id=str(uuid.uuid4()),
        name=name,
        code=_random_code(),
        created_at=datetime.utcnow(),
    )
    _rooms[room.id] = room
    _queues[room.id] = []
    _scores[room.id] = []
    return room


def get_room(room_id: str) -> Optional[Room]:
    return _rooms.get(room_id)


def get_room_by_code(code: str) -> Optional[Room]:
    for room in _rooms.values():
        if room.code == code.upper():
            return room
    return None


def list_rooms() -> List[Room]:
    return [r for r in _rooms.values() if r.is_active]


def close_room(room_id: str) -> bool:
    if room_id in _rooms:
        _rooms[room_id].is_active = False
        return True
    return False


# --- Fila ---

def add_to_queue(room_id: str, song_id: str, singer_name: str) -> Optional[QueueItem]:
    if room_id not in _queues:
        return None
    item = QueueItem(
        id=str(uuid.uuid4()),
        room_id=room_id,
        song_id=song_id,
        singer_name=singer_name,
        added_at=datetime.utcnow(),
    )
    _queues[room_id].append(item)
    return item


def get_queue(room_id: str) -> List[QueueItem]:
    return _queues.get(room_id, [])


def advance_queue(room_id: str) -> Optional[QueueItem]:
    queue = _queues.get(room_id, [])
    waiting = [i for i in queue if i.status == "waiting"]
    if not waiting:
        return None
    next_item = waiting[0]
    next_item.status = "singing"
    return next_item


def finish_current(room_id: str):
    queue = _queues.get(room_id, [])
    for item in queue:
        if item.status == "singing":
            item.status = "done"


# --- Score ---

def add_score(entry: ScoreEntry):
    if entry.room_id not in _scores:
        _scores[entry.room_id] = []
    _scores[entry.room_id].append(entry)


def get_scoreboard(room_id: str) -> List[ScoreEntry]:
    scores = _scores.get(room_id, [])
    return sorted(scores, key=lambda s: s.score, reverse=True)
