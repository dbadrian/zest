import logging

from ..translator import set_language

logger = logging.getLogger(__name__)


def set_language_from_request(request):
    lang = request.query_params.get("lang")
    set_language(lang)
    return lang
