from django.utils import translation


def get_active_language():
    """Gets the currently activate language and locale if present
    e.g, en-us is returned as (en, us)
    """
    raw = translation.get_language().split('-')
    lc, locale = raw if len(raw) >= 2 else (raw[0], None)
    return lc, locale
