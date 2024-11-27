from rest_framework.exceptions import ValidationError


def raise_validation_error(message):
    raise ValidationError({"message": message})