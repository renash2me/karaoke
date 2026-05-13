from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.api.routes import auth, songs, rooms, ws
import os

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

# Serve a webapp do celular
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/app")
async def webapp():
    return FileResponse(os.path.join(static_dir, "index.html"))

@app.get("/health")
async def health():
    return {"status": "ok"}
