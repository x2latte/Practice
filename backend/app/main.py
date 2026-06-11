from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth, users, projects, files
from app.routers.sections import section_routers

app = FastAPI(
    title="TZ API",
    version="1.0.0",
    description="Система управления техническими заданиями",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # в проде — укажи конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Основные роутеры
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(projects.router)
app.include_router(files.router)

# 17 роутеров разделов ТЗ
for r in section_routers:
    app.include_router(r)


@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok"}
