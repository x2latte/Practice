.PHONY: install run migrate-create migrate-run migrate-down         docker docker-stop test lint dump

install:
	python3 -m venv venv && . venv/bin/activate && pip install -r requirements.txt

run:
	. venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

migrate-create:
	. venv/bin/activate && alembic revision --autogenerate -m "$(MSG)"

migrate-run:
	. venv/bin/activate && alembic upgrade head

migrate-down:
	. venv/bin/activate && alembic downgrade -1

docker:
	docker-compose up -d --build

docker-stop:
	docker-compose down

test:
	. venv/bin/activate && pytest -v

lint:
	. venv/bin/activate && ruff check app/

dump:
	docker exec tz_backend_db_1 pg_dump -U tzuser tz_db > dump_$(date +%Y%m%d_%H%M%S).sql
