from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from app.core.auth import authenticate_admin, create_access_token, get_current_admin
from app.models.schemas import TokenResponse

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/token", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    if not authenticate_admin(form_data.username, form_data.password):
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    token = create_access_token({"sub": form_data.username})
    return TokenResponse(access_token=token)


@router.get("/me")
async def me(admin: str = Depends(get_current_admin)):
    return {"username": admin, "role": "admin"}
