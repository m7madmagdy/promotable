fix-lint:
	bin/rubocop -A
build:
	docker compose build
up:
	docker compose up -d
restart:
	docker compose restart
bash:
	docker compose exec app bash
down:
	docker compose down
stop:
	docker compose stop
logs:
	docker compose logs -f app
console:
	docker compose exec app bundle exec rails console
