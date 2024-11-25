CURRENT_DIRECTORY := $(shell pwd)

COMPOSERFLAGS = --build #-d 

help:
	@echo "Docker Compose Help"
	@echo "-----------------------"
	@echo ""
	@echo "Run tests to ensure current state is good:"
	@echo "    make test"
	@echo ""
	@echo "If tests pass, add fixture data and start up the api:"
	@echo "    make begin"
	@echo ""
	@echo "Really, really start over:"
	@echo "    make clean"
	@echo ""
	@echo "See contents of Makefile for more targets."

begin: stop build-backend migrate collectstatic fixtures start

start:
	@docker compose up ${COMPOSERFLAGS}

stop:
	@docker compose stop

status:
	@docker compose ps

restart: stop start

clean-python:
	@find . | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf

clean-frontend:
	@cd frontend && flutter clean && flutter pub get

clean-migrations: stop
	@find . -name \*.pyc -delete
	@find . -path "*/migrations/*.py" -not -name "__init__.py" -delete

docker-clean:
	@docker compose down -v --rmi all --remove-orphans

veryclean: docker-clean clean-migrations

mildclean: clean-migrations
	@docker compose start db
	@docker compose run --rm db psql -h db -U postgres -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
	@docker compose stop

softreset: stop mildclean migrate fixtures

build-backend:
	@docker compose build

build-frontend:
	@echo -e "\e[32mUpdate Flutter Dependencies\e[0m" ; cd ./frontend ; flutter pub get
	@echo -e "\e[32mBuilding Frontend Dtos (might take a while)\e[0m" ; cd ./frontend ; flutter pub run build_runner build --delete-conflicting-outputs

build: build-backend build-frontend

test: test-backend

test-backend: migrate
	@docker compose run --rm backend bash -c 'pytest -vv  --cov-report xml --cov=.'

test-frontend:
	@cd frontend && flutter test

testwarn:
	@docker compose run --rm backend python -Wall manage.py test ${TESTSCOPE}

migrate:
	@docker compose run --rm backend python manage.py makemigrations users shared units foods tags recipes shopping_lists favorites
	@docker compose run --rm backend python manage.py migrate

fixtures:
	@docker compose run --rm backend python manage.py loaddata users.json units.json foods.json tags.json recipes.json recipe_categories.json shoppinglists.json

getfixture:
	@docker compose run --rm backend python manage.py dumpdata ${MODEL} --indent 2

fixtures-from-db:
	@docker compose run --rm backend bash -c '\
		echo -e "\e[32mDumping units\e[0m" && \
		python manage.py dumpdata units --indent 2 > backend/units/fixtures/units.json && \
		echo -e "\e[32mDumping foods\e[0m" && \
		python manage.py dumpdata foods --indent 2 > backend/foods/fixtures/foods.json && \
		echo -e "\e[32mDumping tags\e[0m" && \
		python manage.py dumpdata tags --indent 2 > backend/tags/fixtures/tags.json && \
		echo -e "\e[32mDumping recipes\e[0m" && \
		python manage.py dumpdata recipes --indent 2 > backend/recipes/fixtures/recipes.json && \
		echo -e "\e[32mDumping shoppinglists\e[0m" && \
		python manage.py dumpdata shopping_lists --indent 2 > backend/shopping_lists/fixtures/shoppinglists.json \
	'

flush:
	@docker compose run --rm backend python manage.py flush --noinput

backend-cli:
	@docker compose run --rm backend bash

frontend:
	@bash -c 'cd frontend/flutter && flutter run --no-sound-null-safety -d chrome'

collectstatic:
	@docker compose run --rm backend python manage.py collectstatic

makemessages:
	@docker compose run --rm backend python manage.py makemessages -l ${MLANG}

compilemessages:
	@docker compose run --rm backend python manage.py compilemessages

shell:
	@docker compose run --rm backend python manage.py shell

tail:
	@docker compose logs -f

flake8:
	@docker compose run --rm backend flake8 .

linux-frontend:
	@cd ./frontend ; flutter build linux

.PHONY: start stop status restart clean-migrations build test testwarn migrate fixtures backend-cli frontend-cli frontend tail softreset
