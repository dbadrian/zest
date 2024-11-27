from collections.abc import Iterable
import logging
from typing import List, Dict
from django.db.models import fields
from django.utils import translation
from rest_framework.exceptions import ValidationError
import modeltranslation
from modeltranslation.fields import TranslationFieldDescriptor, NONE
from modeltranslation.utils import (
    get_language,
    build_localized_fieldname,
    resolution_order,
)
from modeltranslation import settings as mt_settings
from modeltranslation.translator import TranslationOptions, Translator
from modeltranslation.utils import parse_field
from shared.utils.generic import contains_keys, to_list
from shared.utils.serializers import raise_validation_error

logger = logging.getLogger(__name__)


def to_multilanguage_representation_impl(value, language_code):
    return {"value": value, "lang": language_code}


def to_multilanguage_representation(data):
    """
    Converts a list of language-specific fields (end with _$(LANG)) to
    the multi-language representation:
    """
    pass


def verify_field_existance(field_or_fields, model):
    for field in to_list(field_or_fields):
        if not hasattr(model, field):
            raise_validation_error(
                f"The (language-specific) field `{field}` does not exist in the model/db."
            )


def from_multilanguage_representation(field_name, data: List[Dict]):
    """
    Converts a multilanguage representation to the internally used fields
    of the model.

    Field should be a single list of dicts (MLR)!
    """
    if not isinstance(data, list):
        raise_validation_error(f"Expected `list of dicts` but got `{type(data)}`!")
    else:
        for el in data:
            if not isinstance(el, dict):
                raise_validation_error(
                    f"Expected `list` of `dicts` but found an element of type `{type(el)}`!"
                )

    decoded = {}
    for mlr_value in data:
        if not contains_keys(mlr_value, ("value", "lang")):
            raise_validation_error(
                f"Supplied dict for translatable field `{field_name}`, did not have both keys `value` and `lang`!"
            )
        lang = mlr_value["lang"]
        lc_field = field_name + "_" + lang
        decoded[lc_field] = mlr_value["value"]
    return decoded


def set_language(lang):
    if lang:
        logger.debug(f"Setting language to {lang} from query arg.")
        translation.activate(lang)


def get_fields_with_lang_extension(model, selection: Iterable = None):
    fields_with_lang_extension = set()
    selection = (
        selection
        if selection is not None
        else translator.get_options_for_model(model).all_fields.keys()
    )
    for k in selection:
        for field in translator.get_options_for_model(model).all_fields[k]:
            fields_with_lang_extension.add(field.name)
    return fields_with_lang_extension


class TranslationFieldDescriptorExtended(TranslationFieldDescriptor):
    """
    A descriptor used for the original translated field.
    """

    def __init__(
        self,
        field,
        fallback_languages=None,
        fallback_value=NONE,
        fallback_undefined=NONE,
    ):
        super().__init__(field, fallback_languages, fallback_value, fallback_undefined)

    def _get_as_dict(self, instance, owner=None):
        if instance is None:
            return self
        default = NONE
        undefined = self.fallback_undefined
        if undefined is NONE:
            default = self.field.get_default()
            undefined = default
        langs = resolution_order(get_language(), self.fallback_languages)
        for lang in langs:
            loc_field_name = build_localized_fieldname(self.field.name, lang)
            val = getattr(instance, loc_field_name, None)
            if self.meaningful_value(val, undefined):
                return to_multilanguage_representation_impl(val, lang)
        if mt_settings.ENABLE_FALLBACKS and self.fallback_value is not NONE:
            logger.error("DISABLE OR FIX THIS")
            return to_multilanguage_representation_impl(
                self.fallback_value, "fallback_value"
            )
        else:
            # raise NotImplementedError(f"Requested field `{default}`")
            if default is NONE:
                default = self.field.get_default()
            # Some fields like FileField behave strange, as their get_default() doesn't return
            # instance of attr_class, but rather None or ''.
            # Normally this case is handled in the descriptor, but since we have overridden it, we
            # must mock it up.
            if isinstance(self.field, fields.files.FileField) and not isinstance(
                default, self.field.attr_class
            ):
                return self.field.attr_class(instance, self.field, default)
            return default

    def __get__(self, instance, owner):
        """
        Returns value from the translation field for the current language, or
        value for some another language according to fallback languages, or the
        custom fallback value, or field's default value, together with the language
        from where it was finally obtained.
        """
        ret = self._get_as_dict(instance, owner)
        return ret if not isinstance(ret, dict) else ret["value"]


class TranslatorExtended(Translator):
    """
    A Translator object encapsulates an instance of a translator. Models are
    registered with the Translator using the register() method.
    """

    def __init__(self):
        super().__init__()

    def _register_single_model(self, model, opts):
        super()._register_single_model(model, opts)
        model_fallback_languages = getattr(opts, "fallback_languages", None)
        model_fallback_values = getattr(opts, "fallback_values", NONE)
        model_fallback_undefined = getattr(opts, "fallback_undefined", NONE)

        # Re"patch" descriptor with our custom version
        for field_name in opts.local_fields.keys():
            field = model._meta.get_field(field_name)
            field_fallback_value = parse_field(model_fallback_values, field_name, NONE)
            field_fallback_undefined = parse_field(
                model_fallback_undefined, field_name, NONE
            )
            descriptor = TranslationFieldDescriptorExtended(
                field,
                fallback_languages=model_fallback_languages,
                fallback_value=field_fallback_value,
                fallback_undefined=field_fallback_undefined,
            )
            setattr(model, field_name, descriptor)


# This global object represents the singleton translator object
translator = TranslatorExtended()
setattr(modeltranslation.translator, "translator", translator)


def register(model_or_iterable, **options):
    """
    Registers the given model(s) with the given translation options.
    The model(s) should be Model classes, not instances.
    Fields declared for translation on a base class are inherited by
    subclasses. If the model or one of its subclasses is already
    registered for translation, this will raise an exception.
    @register(Author)
    class AuthorTranslation(TranslationOptions):
        pass
    """

    def wrapper(opts_class):
        if not issubclass(opts_class, TranslationOptions):
            raise ValueError("Wrapped class must subclass TranslationOptions.")
        translator.register(model_or_iterable, opts_class, **options)
        return opts_class

    return wrapper
