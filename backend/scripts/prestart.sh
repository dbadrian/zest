#!/usr/bin/env bash

alembic revision --autogenerate -m "auto" 
alembic upgrade head
