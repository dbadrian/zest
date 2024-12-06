from allauth.account.adapter import get_adapter
from django.core.exceptions import PermissionDenied
from dj_rest_auth.registration.serializers import (
    RegisterSerializer as DefaultRegisterSerializer,
)


class RegisterSerializer(DefaultRegisterSerializer):

    def run_validation(self, *args, **kwargs):
        raise PermissionDenied()

        # adapter = get_adapter()
        # if not adapter.is_open_for_signup(self.context["request"]):
            # raise PermissionDenied()
        # return super().run_validation(*args, **kwargs)
