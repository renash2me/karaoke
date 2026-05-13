from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import auth, songs, rooms, ws

app = FastAPI(
    title="Karaoké API",
    description="Backend do sistema de karaokê self-hosted",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(songs.router)
app.include_router(rooms.router)
app.include_router(ws.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
