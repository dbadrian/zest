import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true)
class Tag with _$Tag {
  factory Tag({
    required String id,
    required String text,
  }) = _Tag;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  // Map<String, dynamic> toJson() {
  //   return _$TagToJson(this);
  // }
}
