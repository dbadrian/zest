import os

LOGGING_LEVEL = os.getenv("DJANGO_LOG_LEVEL", "INFO")
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "coloredlogs": {
            "()": "coloredlogs.ColoredFormatter",
            "fmt": "[%(asctime)s] %(hostname)s %(name)s %(levelname)s %(message)s",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "level": LOGGING_LEVEL,
            "formatter": "coloredlogs",
            "filters": ["hostname",],
        },
    },
    "filters": {
        "hostname": {
            "()": "coloredlogs.HostNameFilter",
        },
    },
    "loggers": {
        "": {
            "handlers": ["console",],
            "level": LOGGING_LEVEL,
        },
        "botocore": {
            "handlers": ["console"],
            "level": "WARNING",
        },
        "boto3": {
            "handlers": ["console"],
            "level": "WARNING",
        },
    },
}
