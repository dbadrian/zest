import logging

logger = logging.getLogger(__name__)


def get_scale_from_query_param(context):
    request = context.get("request", None)
    if request:
        return int(request.query_params.get("scale", 1))
    else:
        return 1
