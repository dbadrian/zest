"""Gunicorn *production* config file"""

import os
from distutils.util import strtobool
import getpass

USER = getpass.getuser()

# Django WSGI application path in pattern MODULE_NAME:VARIABLE_NAME
wsgi_app = "zest.wsgi:application"
# The granularity of Error log outputs
loglevel = "info"
# The number of worker processes for handling requests
workers = int(os.getenv("GU_WORKERS", 2))
threads = int(os.getenv("GU_THREADS", 1))
# The socket to bind
bind = os.getenv("GU_BIND", "0.0.0.0:8000")
# Restart workers when code changes (development only!)
reload = bool(strtobool(os.getenv("GU_RELOAD", "false")))
# Write access and error info to /var/log
# accesslog = errorlog = "/var/log/gunicorn/production.log"
base_log_path = os.getenv("LOGS_PATH", f"/home/{USER}")

accesslog = f'{base_log_path}/gunicorn_acc.log'
errorlog = f'{base_log_path}/gunicorn_err.log'

access_log_format = (
    "%(h)s %(l)s %(u)s %(t)s '%(r)s' %(s)s %(b)s '%(f)s' '%(a)s' in %(D)sµs"
)
# Redirect stdout/stderr to log file
capture_output = True
# PID file so you can easily fetch process ID
# pidfile = "/var/run/gunicorn/prod.pid"
pidfile = f"/home/{USER}/gunicorn.pid"
# Daemonize the Gunicorn process (detach & enter background)
daemon = False
