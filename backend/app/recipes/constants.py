from enum import Enum


class UnitSystem(str, Enum):
    METRIC = "Metric"
    IMPERIAL = "imp."
    US = "US"
    JAP = "Shakkanhou"
    DIMENSIONLESS = ""


class BaseUnit(str, Enum):
    KILOGRAM = "kg"
    LITER = "l"


MAX_DEFAULT_NAME_LENGTH = 128
MAX_RECIPE_NAME_LENGTH = 256
