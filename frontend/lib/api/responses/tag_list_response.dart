import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/tag.dart';
import 'pagination.dart';

part 'tag_list_response.freezed.dart';
part 'tag_list_response.g.dart';

@freezed
class TagListResponse with _$TagListResponse {
  factory TagListResponse({
    required PaginationResponse pagination,
    required List<Tag> tags,
  }) = _TagListResponse;

  factory TagListResponse.fromJson(Map<String, dynamic> json) =>
      _$TagListResponseFromJson(json);

  @override
  String toString() {
    return 'TagListResponse{Lenght: ${tags.length}}';
  }
}
