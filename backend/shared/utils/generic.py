from typing import Union, Any, List
from collections.abc import Iterable
from functools import reduce

from django.utils.translation import gettext_lazy as _
from django.core.exceptions import ValidationError


def get_first_key(d):
    """Return "first" key, where first is given by the default iterators order."""
    return next(iter(d))


def get_first_value(d):
    """Return "first" value, where first is given by the default iterators order."""
    return d[get_first_key(d)]


def get_first_key_value_pair(d):
    """Return "first" key-value pair, where first is given by the default iterators order."""
    k = get_first_key(d)
    return k, d[k]


def contains_keys(dictionary: dict, keys: Union[list, tuple]):
    """Check if a dictionary contains all of the keys given by an iterable keys"""
    return all(k in dictionary for k in keys)


def to_list(value_or_iterable: Union[Any, List], do_not_convert_iterables=False) -> List[Any]:
    """
    Converts iterables (excluding strings) to a list, wraps a single value
    by a list and preserves lists as list.
    """
    if isinstance(value_or_iterable, str):
        # handle strings separately
        return [value_or_iterable]

    if not do_not_convert_iterables and isinstance(value_or_iterable, Iterable):
        return list(value_or_iterable)  # implict conversion
    else:
        return [value_or_iterable]


def XOR(container):
    return reduce(lambda x, y: x ^ y, container)


def none_or_all(container):
    return XOR([element is None for element in container])


def check_dependent_fields(field_1, field_2, field_1_name, field_2_name, bidirectional=False):
    if none_or_all([field_1, field_2]):
        if bidirectional:
            raise ValidationError(
                _(
                    f"Either none or both `{field_1_name}` and `{field_2_name}` need to be set!"
                )
            )
        else:
            raise ValidationError(
                _(f"Set `{field_1_name}` when setting `{field_2_name}`!")
            )
