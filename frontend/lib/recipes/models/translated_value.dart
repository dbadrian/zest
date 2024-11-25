import 'package:freezed_annotation/freezed_annotation.dart';

part 'translated_value.freezed.dart';
part 'translated_value.g.dart';

@freezed
class TranslatedValue with _$TranslatedValue {
  const TranslatedValue._();
  @JsonSerializable(explicitToJson: true)
  const factory TranslatedValue({
    required String value,
    required String lang,
  }) = _TranslatedValue;

  factory TranslatedValue.fromJson(Map<String, dynamic> json) =>
      _$TranslatedValueFromJson(json);

  // Map<String, dynamic> toJson() {
  //   return _$TranslatedValueToJson(this);
  // }
}
