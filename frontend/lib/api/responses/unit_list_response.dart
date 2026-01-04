import 'package:freezed_annotation/freezed_annotation.dart';

import '../../recipes/models/unit.dart';
import 'pagination.dart';

part 'unit_list_response.freezed.dart';
part 'unit_list_response.g.dart';

@freezed
class UnitListResponse with _$UnitListResponse {
  factory UnitListResponse({
    required PaginationMeta pagination,
    required List<Unit> units,
  }) = _UnitListResponse;

  factory UnitListResponse.fromJson(Map<String, dynamic> json) =>
      _$UnitListResponseFromJson(json);

  @override
  String toString() {
    return 'UnitListResponse{Lenght: ${units.length}}';
  }
}
