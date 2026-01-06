import 'package:freezed_annotation/freezed_annotation.dart';

part 'multilingual_data_response.freezed.dart';
part 'multilingual_data_response.g.dart';

@freezed
abstract class MultilingualData with _$MultilingualData {
  const factory MultilingualData({
    required Map<String, dynamic> en,
    required Map<String, dynamic> de,
  }) = _MultilingualData;

  const MultilingualData._();

  Map<String, dynamic> getByLanguage(String language) {
    switch (language) {
      case 'en':
        return en;
      case 'de':
        return de;
      default:
        return en;
    }
  }

  factory MultilingualData.fromJson(Map<String, dynamic> json) =>
      _$MultilingualDataFromJson(json);
}
