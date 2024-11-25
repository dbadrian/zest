import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination.freezed.dart';
part 'pagination.g.dart';

@freezed
class PaginationResponse with _$PaginationResponse {
  factory PaginationResponse({
    String? next,
    String? previous,
    @JsonKey(name: "total_results") required int totalResults,
    @JsonKey(name: "total_pages") required int totalPages,
    @JsonKey(name: "current_page") required int currentPage,
  }) = _Pagination;

  factory PaginationResponse.fromJson(Map<String, dynamic> json) =>
      _$PaginationResponseFromJson(json);
}

class PaginationRequest {
  PaginationRequest({required this.page, this.pageSize});
  final int page;
  final int? pageSize;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaginationRequest &&
        other.pageSize == pageSize &&
        other.page == page;
  }

  @override
  int get hashCode => pageSize.hashCode ^ page.hashCode;
}
