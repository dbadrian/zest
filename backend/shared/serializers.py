from datetime import datetime, time, date
import logging
import decimal
from collections import OrderedDict, defaultdict
from collections.abc import Iterable
from typing import Any, Dict, List, Tuple, Type, Union
from django.db import models
from django.core.exceptions import ObjectDoesNotExist
from django.utils.formats import localize_input
from modeltranslation.manager import get_translatable_fields_for_model
from rest_framework.exceptions import ValidationError
from rest_framework import serializers
from rest_framework import fields
from rest_framework.settings import api_settings
import drf_serpy as serpy
from shared.translator import (
    TranslationFieldDescriptorExtended,
    from_multilanguage_representation,
    get_fields_with_lang_extension,
    verify_field_existance,
)
from shared.utils.serializers import raise_validation_error
from shared.utils.generic import get_first_key
from drf_yasg import openapi

logger = logging.getLogger(__name__)


class SerpyContextSerializer(serpy.Serializer):

    def _serialize(self, instance: Type[Any], fields: Tuple):
        v = {}
        for name, getter, to_value, call, required, pass_self in fields:
            if pass_self:
                result = getter(self, instance)
            else:
                try:
                    result = getter(instance)
                except (KeyError, AttributeError):
                    if required:
                        raise
                    else:
                        continue
                if required or result is not None:
                    if call:
                        result = result()
                    # we can have blank values, hence our overload here...
                    if to_value and result is not None:
                        result = to_value(result)
            v[name] = result

        return v

    def to_value(self, instance: Type[Any]) -> Union[Dict, List]:
        fields: Tuple = self._compiled_fields

        for f in fields:
            # get the serializer s from the bound-method (to value) to inject the context
            if f[2] is not None:
                if (s := getattr(f[2], "__self__", None)) is not None:
                    # print(type(s), isinstance(s, SerpyContextSerializer))
                    if isinstance(s, SerpyContextSerializer):
                        s.context = self.context

        if self.many:
            serialize = self._serialize
            # django orm support for m2m fields
            if getattr(instance, "all", None):
                return [serialize(o, fields) for o in instance.all()]
            return [serialize(o, fields) for o in instance]
        return self._serialize(instance, fields)


class SerpyDateTimeISOTZField(serpy.Field):
    """A `Field` that converts the value to a date format."""

    date_format = "%Y-%m-%d"
    schema_type = openapi.TYPE_STRING

    def __init__(self, date_format: str = None, **kwargs):
        super().__init__(**kwargs)
        self.date_format = date_format or self.date_format

    def to_value(self, value: Union[datetime, time, date]) -> str:
        if value:
            return value.astimezone().isoformat()
            # return value.strftime(self.date_format)


class SerpyFloatFieldDefault(serpy.Field):
    """A `Field` that converts the value to a float."""

    getter_takes_serializer = False

    def __init__(self, default: float, **kwargs):
        super().__init__(**kwargs)
        self.default = default

    def as_getter(self, serializer_field_name: str, serializer_cls: Type):
        ret = super().as_getter(serializer_field_name, serializer_cls)
        if ret is None:
            return lambda o: getattr(o, "similarity", self.default)
        else:
            return ret

    # to_value = staticmethod(float)

    def to_value(self, value: float) -> str:
        if value:
            return value
        return self.default

    schema_type = openapi.TYPE_NUMBER


class SerpyKeyField(serpy.Field):
    def to_value(self, value):
        return str(value.id)


class NormalizedDecimalField(fields.DecimalField):

    def to_representation(self, value):
        coerce_to_string = getattr(
            self, "coerce_to_string", api_settings.COERCE_DECIMAL_TO_STRING
        )

        if not isinstance(value, decimal.Decimal):
            value = decimal.Decimal(str(value).strip())

        value = value.normalize()
        # quantized = self.quantize(value)

        # if not coerce_to_string:
        #     return quantized
        # if self.localize:
        #     return localize_input(quantized)

        return "{:f}".format(value)


class NormalizedDecimalFieldMixin(serializers.Serializer):
    """Replaces the automatic mapping from DecimalField to custom NormalizedDecimalField"""

    def __init__(self, *args, **kwargs):
        self.serializer_field_mapping[models.DecimalField] = NormalizedDecimalField
        super().__init__(*args, **kwargs)


class NonNullModelSerializerMixinSerpy(object):

    @staticmethod
    def _check_dict_null_value(d):
        # FIXME: the "None" is always gonna cause problems
        return {k: v for k, v in d.items() if v != "None" and v is not None}

    def to_value(self, instance: Type[Any]) -> Dict:
        ret = super().to_value(instance)

        if isinstance(ret, list):
            return [self._check_dict_null_value(o) for o in ret]

        return self._check_dict_null_value(ret)


class NonEmptyStringSerializerMixinSerpy(object):

    @staticmethod
    def _check_dict_empty_string(d):
        return {k: v for k, v in d.items() if v != ""}

    def to_value(self, instance: Type[Any]) -> Dict:

        ret = super().to_value(instance)

        if isinstance(ret, list):
            return [self._check_dict_empty_string(o) for o in ret]

        return self._check_dict_empty_string(ret)


class TranslatedModelSerializerMixinSerpy:

    def to_value(self, instance: Type[Any]) -> Union[Dict, List]:
        fields: Tuple = self._compiled_fields
        # lc = "en"  # self.context.get("lang", None)
        new_fields = []
        for f in fields:
            if (desc := getattr(self.Meta.model, f[0], None)) is not None:
                if type(desc) == TranslationFieldDescriptorExtended:
                    new_fields.append(
                        (
                            f[0],
                            desc._get_as_dict,
                            lambda x: [x] if x is not None else None,
                            False,
                            f[4],
                            False,
                        )
                    )
                else:
                    new_fields.append(f)
            else:
                # computed method?
                new_fields.append(f)

        fields = new_fields

        if self.many:
            serialize = self._serialize
            # django orm support for m2m fields
            if getattr(instance, "all", None):
                return [serialize(o, fields) for o in instance.all()]
            return [serialize(o, fields) for o in instance]
        return self._serialize(instance, fields)


class TranslatedModelSerializer:

    def __init__(self, *args, **kwargs):
        if (context := kwargs.get("context", None)) and context.get(
            "lang", None
        ) == "all":
            # TODO: add only those that are actually supposed to be serialized!
            tfc = self.get_translatable_fields_with_lang_extension()
            fields = set(self.Meta.fields)
            new_fields = list(self.Meta.fields)
            for f in tfc:
                if f not in fields:
                    new_fields.append(f)

            self.Meta.fields = new_fields

        # Instantiate the superclass normally
        super().__init__(*args, **kwargs)

    def _add_additional_language_fields_from_context(self, instance, ret):
        fields = self.get_translatable_fields()
        for f in fields:

            ret[f] = []
            for flang in self.get_translatable_fields_with_lang_extension(
                selection=[f]
            ):
                _, lang = flang.rsplit("_", 1)
                if (r := ret.pop(flang, None)) is not None:  # drop null values
                    ret[f].append({"value": r, "lang": lang})
                # ret.pop(flang, None)

    def _wrap_translatable_fields(self, instance, ret):
        fields = self.get_translatable_fields()
        for f in fields:
            if obj := getattr(self.Meta.model, f):
                if vals := obj._get_as_dict(instance, None):
                    ret[f] = [vals]

            flang = self.get_translatable_fields_with_lang_extension(selection=[f])
            for fl in flang:
                ret.pop(fl, None)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if self.context.get("lang", None) == "all":
            self._add_additional_language_fields_from_context(instance, ret)
        else:
            self._wrap_translatable_fields(instance, ret)
        return ret

    def get_translatable_fields(self):
        return set(get_translatable_fields_for_model(self.Meta.model))

    def get_translatable_fields_with_lang_extension(self, selection: Iterable = None):
        return get_fields_with_lang_extension(self.Meta.model, selection=selection)

    def _extract_language_fields(self, data):
        language_field_data = {}
        present_multilanguage_fields = set()
        # Look for multi-language representations
        translatable_fields = self.get_translatable_fields()
        for field in translatable_fields:
            if f_data := data.pop(field, None):
                present_multilanguage_fields.add(field)
                language_field_data.update(
                    from_multilanguage_representation(field, f_data)
                )

        # Look for already language-specific fields (also allowed)
        # might overwrite
        for field in self.get_translatable_fields_with_lang_extension():
            if f_data := data.pop(field, None):
                present_multilanguage_fields.add(field.split("_")[0])
                language_field_data[field] = f_data

        # check if the field exists (e.g., non-supported language (code))
        verify_field_existance(language_field_data.keys(), self.Meta.model)

        return language_field_data, present_multilanguage_fields

    def _get_required_fields(self):
        return {name for name, field in self.get_fields() if field.required}

    def to_internal_value(self, data):
        """
        Extendes the deserialization and validation behavior, by checking if a translateble field
        is given as dict (as on serialisation) and processes it using the standard validation behavior.
        """
        # Process any translatable field; will remove those from data
        language_field_data, present_multilanguage_fields = (
            self._extract_language_fields(data)
        )

        # Add fake "field" data to avoid any lower-level validation erroring
        # TODO: This could be replaced by completely replacing the "to_internal_value" logic
        # on the super level
        data.update(
            {
                field_name: "just_some_dummy_magic_valueQ@*$&*163"
                for field_name in present_multilanguage_fields
            }
        )
        validated_data = super().to_internal_value(data)
        for field_name in present_multilanguage_fields:
            validated_data.pop(field_name)

        # manually call validation on language-specific fields with the
        # generic field-validators (iteratively)
        for name, d in language_field_data.items():
            field_name = name.rsplit("_", 1)[0]
            # TODO: not sure about the uniquetogether ones etc.
            if validator := getattr(self, f"validate_{field_name}", None):
                validator(d)

        data.update(validated_data | language_field_data)
        return validated_data | language_field_data


class NonNullModelSerializerMixin(object):

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # return OrderedDict([(key, ret[key]) for key in ret if ret[key] is not None])
        return {key: ret[key] for key in ret if ret[key] is not None}


class NonEmptyStringModelSerializerMixin(object):

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # return OrderedDict([(key, ret[key]) for key in ret if ret[key] != ""])
        return {key: ret[key] for key in ret if ret[key] != ""}


class ModelDeduplicationMixin(object):

    def _get_instance_by_field_and_value(self, field, value):
        search = {field: value}
        try:
            return self.Meta.model.objects.get(**search)  # pylint: disable=no-member
        except self.Meta.model.DoesNotExist:
            return None

    def to_internal_value(self, data):
        # Convert the multi-lingual representation first
        vdata = super().to_internal_value(data)

        # Find potential conflicts or deduplication possibilities
        candidates = defaultdict(list)
        for field in self.get_translatable_fields_with_lang_extension():
            if data := vdata.get(field, None):
                obj = self._get_instance_by_field_and_value(field, data)
                if obj:
                    candidates[obj].append(field)

        if (noc := len(candidates)) > 1:
            raise_validation_error(
                f"Ambigious request. Found multiple objects (partially) matching the request."
            )
        elif noc == 1:
            obj = get_first_key(candidates)
            if "id" not in vdata:
                # although its a deduplication candidate, we need to check all supplied_field
                # if they might conflict with the found object
                for field, value in vdata.items():
                    # only if orf is not None  or not "" -> compare
                    if (orf := getattr(obj, field, None)) and value != orf:
                        raise_validation_error(
                            f"Found matching object for field(s) '{', '.join(candidates[obj])}', but mismatch for {field}: '{orf}' and '{value}'."
                        )
                vdata["id"] = obj.id
            elif obj.id != vdata["id"]:
                raise_validation_error(
                    f"Found already existing instance with same content for field '{field}'. Update not possible."
                )
            else:
                # new object / or for sure a valid update to existing one
                pass
        else:
            # new object / or for sure a valid update to existing one
            pass

        return vdata


def update_nested_field(
    parent_instance, data, field_name, related_name, field_class=None, copy_on_pk=False
):
    """Handles the updating of nested many-to-many fields

        TODO: actually document how the eff this works
    Args:
        parent_instance ([type]): [description]
        data ([type]): [description]
        field_name ([type]): [description]
        related_name ([type]): [description]
        field_class ([type], optional): [description]. Defaults to None.
        copy_on_pk (bool, optional): [description]. Defaults to False.

    Raises:
        ValidationError: [description]

    Returns:
        [type]: [description]
    """
    entries_to_keep = set()

    field = getattr(parent_instance, field_name)
    all_objects = field if field_class is None else field_class.objects
    if data:
        for entry in data:
            if eid := entry.get("id", None):
                try:
                    obj = all_objects.get(
                        id=eid
                    )  # dont move! implicitly validates existance!
                    entries_to_keep.add(eid)
                    if not copy_on_pk:
                        for k, v in entry.items():
                            setattr(obj, k, v)
                    obj.save()

                    # handle ManyToMany-relationships my adding to new obj
                    if hasattr(field, "add"):
                        field.add(obj)
                except ObjectDoesNotExist:
                    raise ValidationError(
                        {
                            "message": f"Primary key/id submitted, but no object with that id exists."
                        }
                    )
            else:
                obj = field.create(**entry)
                entries_to_keep.add(obj.id)

    # Delete all those items no longer listed
    to_delete = all_objects.filter(id__in=field.all()).exclude(id__in=entries_to_keep)
    to_delete.delete()

    return parent_instance
