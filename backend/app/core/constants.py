USERNAME_MIN_LENGTH = 3
USERNAME_MAX_LENGTH = 254
EMAIL_MAX_LENGTH = 254  # given by RFC 3696
PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128
PASSWORD_SPECIAL_CHARS = r'[!@#$%^&*(),.?":{}|<>]'

USERNAME_REGEX_PATTERN = r"^[a-zA-Z0-9_-]+$"
EMAIL_REGEX_PATTERN = r"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$"
