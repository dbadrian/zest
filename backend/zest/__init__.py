from .version import __version__

# used for statically built files / shiv
def main():
    import os
    import sys

    import django

    # setup django
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "zest.settings")
    django.setup()

    try:
        production = sys.argv[1] == "production"
    except IndexError:
        production = False

    if production:
        import gunicorn.app.wsgiapp as wsgi

        # This is just a simple way to supply args to gunicorn
        sys.argv = ["-c", "config/gunicorn/prod.py"]

        wsgi.run()
    else:
        from django.core.management import call_command

        call_command("runserver")
