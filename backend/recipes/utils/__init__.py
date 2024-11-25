import logging

from rest_framework import serializers

logger = logging.getLogger(__name__)


def create_from_serializer(serializer, data):
    # Update instruction groups
    s = serializer()
    for datum in data:
        s.create(datum)


def update_nested_positional_group(
    outer_element,
    new_data,
    object_class,
    pk_name="id",
    position_name="position",
    group_name="group",
):
    keep_pks = set()  # store primary keys of objects that are kept
    for new_pos, datum in enumerate(new_data, start=1):
        datum[position_name] = new_pos  # overwrite whatever is supplied

        if pk_name in datum.keys():
            pk = datum[pk_name]
            if pk in keep_pks:
                logger.debug(f"Too many occurances of primary key `{pk_name}={pk}` in update!")
                raise serializers.ValidationError(f"Too many occurances of primary key `{pk_name}={pk}` in update!")

            filters = {pk_name: pk, group_name: getattr(outer_element, pk_name)}

            qs = object_class.objects.filter(**filters)
            if qs.exists():
                qs.update(**datum)
                keep_pks.add(pk)
            else:
                logger.debug(f"Supplied primary key `{pk_name}={pk}` for {object_class} of does not exist in database!")
                raise serializers.ValidationError(f"Supplied primary key `{pk_name}={pk}` does not exist in database!")

        else:
            datum[group_name] = outer_element
            o = object_class.objects.create(**datum)
            keep_pks.add(getattr(o, pk_name))

    # Remove existing entries not included in the update for this group
    filters = {group_name: getattr(outer_element, pk_name)}
    for i in object_class.objects.filter(**filters):
        if getattr(i, pk_name) not in keep_pks:
            i.delete()
