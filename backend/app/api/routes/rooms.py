from fastapi import APIRouter, HTTPException, Depends
from typing import List
from pydantic import BaseModel
from app.models.schemas import Room, QueueItem, ScoreEntry, ScoreUpdate
from app.services import rooms as room_service
from app.core.auth import get_current_admin
from datetime import datetime

router = APIRouter(prefix="/api/rooms", tags=["rooms"])


class CreateRoomRequest(BaseModel):
    name: str


class JoinRoomRequest(BaseModel):
    code: str


class AddToQueueRequest(BaseModel):
    song_id: str
    singer_name: str


# --- Salas ---

@router.post("/", response_model=Room, dependencies=[Depends(get_current_admin)])
async def create_room(req: CreateRoomRequest):
    return room_service.create_room(req.name)


@router.get("/", response_model=List[Room], dependencies=[Depends(get_current_admin)])
async def list_rooms():
    return room_service.list_rooms()


@router.post("/join", response_model=Room)
async def join_room(req: JoinRoomRequest):
    room = room_service.get_room_by_code(req.code)
    if not room or not room.is_active:
        raise HTTPException(status_code=404, detail="Sala não encontrada")
    return room


@router.delete("/{room_id}", dependencies=[Depends(get_current_admin)])
async def close_room(room_id: str):
    if not room_service.close_room(room_id):
        raise HTTPException(status_code=404, detail="Sala não encontrada")
    return {"ok": True}


# --- Fila ---

@router.get("/{room_id}/queue", response_model=List[QueueItem])
async def get_queue(room_id: str):
    return room_service.get_queue(room_id)


@router.post("/{room_id}/queue", response_model=QueueItem)
async def add_to_queue(room_id: str, req: AddToQueueRequest):
    item = room_service.add_to_queue(room_id, req.song_id, req.singer_name)
    if not item:
        raise HTTPException(status_code=404, detail="Sala não encontrada")
    return item


@router.post("/{room_id}/queue/advance", dependencies=[Depends(get_current_admin)])
async def advance_queue(room_id: str):
    item = room_service.advance_queue(room_id)
    if not item:
        raise HTTPException(status_code=404, detail="Fila vazia")
    return item


@router.post("/{room_id}/queue/finish", dependencies=[Depends(get_current_admin)])
async def finish_current(room_id: str):
    room_service.finish_current(room_id)
    return {"ok": True}


# --- Score ---

@router.post("/{room_id}/score")
async def submit_score(room_id: str, update: ScoreUpdate):
    room = room_service.get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Sala não encontrada")
    entry = ScoreEntry(
        room_id=room_id,
        singer_name=update.singer_name,
        song_id="",
        score=update.score,
        accuracy=update.accuracy,
        sung_at=datetime.utcnow(),
    )
    room_service.add_score(entry)
    return {"ok": True}


@router.get("/{room_id}/scoreboard", response_model=List[ScoreEntry])
async def get_scoreboard(room_id: str):
    return room_service.get_scoreboard(room_id)


@router.delete("/{room_id}/queue/{item_id}")
async def remove_from_queue(room_id: str, item_id: str, singer_name: str):
    """Remove um item da fila — só permite remover itens do próprio cantor"""
    queue = room_service.get_queue(room_id)
    for item in queue:
        if item.id == item_id and item.singer_name == singer_name and item.status == "waiting":
            item.status = "done"
            return {"ok": True}
    from fastapi import HTTPException
    raise HTTPException(status_code=403, detail="Item não encontrado ou não pertence a você")


@router.post("/{room_id}/queue/done")
async def mark_done(room_id: str):
    """Remove o primeiro item waiting da fila (marca como done)"""
    queue = room_service.get_queue(room_id)
    for item in queue:
        if item.status == "waiting":
            item.status = "done"
            break
    return {"ok": True}
