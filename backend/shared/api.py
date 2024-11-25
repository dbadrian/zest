from rest_framework.response import Response
from rest_framework import status

from shared.utils.api import set_language_from_request


class ReturnDictMixin:
    """
    Apply this mixin to a DRF viewset to get wrap the normal returned array,
    in a dict, the models verbose_name_plural as key.

    It is recommened to explictly set verbose_name_plural, but django
    will automatically conjure one up in any case.
    """

    def list(self, request, *args, **kwargs):
        if (
            meta := getattr(self.get_serializer(*args, **kwargs), "Meta", None)
        ) is not None:
            name = self.get_serializer(
                *args, **kwargs
            ).Meta.model._meta.verbose_name_plural
        else:
            name = self.get_serializer(*args, **kwargs).name_plural

        name = name.lower().replace(" ", "_")
        response = super().list(request, *args, **kwargs)
        response.data[name] = response.data.pop("results", None)
        return response


class ReadWriteSerializerMixin:
    """
    Overrides get_serializer_class to choose the read serializer
    for GET requests and the write serializer for POST requests.

    Set read_serializer_class and write_serializer_class attributes on a
    viewset.

    Attribution: https://www.revsys.com/tidbits/using-different-read-and-write-serializers-django-rest-framework/
    """

    read_serializer_class = None
    write_serializer_class = None

    def get_serializer_class(self):
        # print(">>>>>", self.action)
        if self.action in ["create", "update", "partial_update", "destroy"]:
            return self.get_write_serializer_class()

        return self.get_read_serializer_class()

    def get_read_serializer_class(self):
        assert self.read_serializer_class is not None, (
            "'%s' should either include a `read_serializer_class` attribute,"
            "or override the `get_read_serializer_class()` method."
            % self.__class__.__name__
        )
        return self.read_serializer_class

    def get_write_serializer_class(self):
        assert self.write_serializer_class is not None, (
            "'%s' should either include a `write_serializer_class` attribute,"
            "or override the `get_write_serializer_class()` method."
            % self.__class__.__name__
        )
        return self.write_serializer_class


class TranslatedModelCreationMixin:
    """Mixing to be used if a model uses"""

    def create(self, request, *args, **kwargs):
        _ = set_language_from_request(self.request)
        return super().create(request, *args, **kwargs)


class FullResponseSerializeMixin:
    """
    Ensures that the full object instance is "serialized" and returned
    instead of the potentially truncated version the custom write serializer might produce
    """

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)

        output_serializer = self.read_serializer_class(serializer.instance)
        headers = self.get_success_headers(output_serializer.data)
        return Response(
            output_serializer.data, status=status.HTTP_201_CREATED, headers=headers
        )

    def update(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        output_serializer = self.read_serializer_class(serializer.instance)
        headers = self.get_success_headers(output_serializer.data)
        return Response(
            output_serializer.data, status=status.HTTP_200_OK, headers=headers
        )

    def partial_update(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_partial_update(serializer)

        output_serializer = self.read_serializer_class(serializer.instance)
        headers = self.get_success_headers(output_serializer.data)
        return Response(
            output_serializer.data, status=status.HTTP_200_OK, headers=headers
        )
