import multiprocessing
from pathlib import Path

BASE_DIR = Path("/home/zest/zest")
LOG_DIR = BASE_DIR / "shared" / "logs"

bind = "127.0.0.1:8000"

workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "uvicorn.workers.UvicornWorker"

timeout = 60
graceful_timeout = 30
keepalive = 5

# --- Logging ---
accesslog = str(LOG_DIR / "gunicorn-access.log")
errorlog = str(LOG_DIR / "gunicorn-error.log")
loglevel = "info"

proc_name = "myapp"

# Preload app (see note below)
preload_app = False

