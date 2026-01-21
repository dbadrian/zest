String? emptyValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Field must be filled';
  }
  return null;
}

String? emptyListValidator<T>(List<T>? value) {
  if (value == null || value.isEmpty) {
    return 'Choose at least one!';
  }
  return null;
}

String? urlValidator(String? value) {
  final RegExp urlRegex_ = RegExp(
      r"^(?:http|https):\/\/[\w\-_]+(?:\.[\w\-_]+)+[\w\-.,@?^=%&:/~\\+#]*$");
  if (value != null && value.isNotEmpty && !urlRegex_.hasMatch(value)) {
    return 'Not a valid url';
  }
  return null;
}

String? fractionalValidator(String? value,
    {double maxFractionalPart = 0.0001}) {
  if (value == null) {
    return "Can't validate fractional part of empty number.";
  }
  final number = double.tryParse(value) ?? 0;
  final fraction = number - number.truncate();
  // if (number < 0.00001) {
  //   return "Number should be non-zero.";
  // }
  if ((number > 0 && number < 1 && fraction < maxFractionalPart) ||
      (fraction > 0.00000001 && (fraction - maxFractionalPart) > 0)) {
    return "Too many decimal positions.";
  }
  return null;
}

String? minValueValidator(String? value,
    {required double minValue, String? customError, bool forceInt = false}) {
  if (value == null) {
    return "Can't validate fractional part of empty number.";
  }
  final number = double.tryParse(value) ?? 0;
  if (number < minValue) {
    return customError ??
        "Needs to be larger than or equal to ${forceInt ? minValue.toInt() : minValue}.";
  }
  return null;
}

String? maxValueValidator(String? value,
    {required double maxValue, String? customError, bool forceInt = false}) {
  if (value == null) {
    return "Can't validate fractional part of empty number.";
  }
  final number = double.tryParse(value) ?? 0;
  if (number > maxValue) {
    return customError ??
        "Needs to be smaller than or equal to ${forceInt ? maxValue.toInt() : maxValue}.";
  }
  return null;
}

String? chainValidators(value, List<String? Function(String?)> validators) {
  for (final validate in validators) {
    final b = validate(value);
    if (b != null) return b;
  }
  return null;
}
