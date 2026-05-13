from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    media_path: str = "/media"
    data_path: str = "/app/data"
    admin_username: str = "admin"
    admin_password: str = "changeme"
    secret_key: str = "dev-secret-key"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 dias

    class Config:
        env_file = ".env"


settings = Settings()
