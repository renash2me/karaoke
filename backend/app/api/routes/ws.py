from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, List
import json

router = APIRouter(tags=["websocket"])

# room_id -> lista de conexões ativas
_connections: Dict[str, List[WebSocket]] = {}


async def broadcast(room_id: str, message: dict):
    connections = _connections.get(room_id, [])
    disconnected = []
    for ws in connections:
        try:
            await ws.send_text(json.dumps(message))
        except Exception:
            disconnected.append(ws)
    for ws in disconnected:
        connections.remove(ws)


@router.websocket("/ws/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str):
    await websocket.accept()

    if room_id not in _connections:
        _connections[room_id] = []
    _connections[room_id].append(websocket)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            # Propaga a mensagem para todos na sala
            await broadcast(room_id, message)

    except WebSocketDisconnect:
        if room_id in _connections:
            _connections[room_id].remove(websocket)
