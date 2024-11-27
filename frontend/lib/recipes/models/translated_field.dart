import 'package:freezed_annotation/freezed_annotation.dart';

import 'translated_value.dart';

part 'translated_field.freezed.dart';
part 'translated_field.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true)
class TranslatedField with _$TranslatedField {
  const TranslatedField._();
  @JsonSerializable(explicitToJson: true)
  factory TranslatedField({
    @Default([]) List<TranslatedValue> values,
  }) = _TranslatedField;

  factory TranslatedField.fromJson(List<Map<String, dynamic>> json) {
    return TranslatedField(
        values: List<TranslatedValue>.from(
            json.map((e) => TranslatedValue.fromJson(e))));
  }

  List<Map<String, dynamic>> toJson() {
    return List<Map<String, dynamic>>.from(values.map((e) => e.toJson()));
  }

  // factory TranslatedField.fromJson(Map<String, dynamic> json) =>
  //     _$TranslatedFieldFromJson(json);

  String value() {
    if (values.isNotEmpty) {
      return values[0].value;
    } else {
      return "";
    }
  }

  String activeLanguage() {
    if (values.isNotEmpty) {
      return values[0].lang;
    } else {
      return "";
    }
  }

  List<String> availableLanguages() {
    return List<String>.from(values.map((e) => e.lang));
  }

  Map<String, String> availableLanguagesMap() {
    return {
      for (var item in values) item.lang: item.value,
    };
  }
}
