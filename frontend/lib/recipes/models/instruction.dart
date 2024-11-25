import 'package:freezed_annotation/freezed_annotation.dart';

part 'instruction.freezed.dart';
part 'instruction.g.dart';

@freezed
// @JsonSerializable(explicitToJson: true)
class Instruction with _$Instruction {
  factory Instruction({
    required String text,
  }) = _Instruction;

  factory Instruction.fromJson(Map<String, dynamic> json) =>
      _$InstructionFromJson(json);

  // Map<String, dynamic> toJson() {
  //   return _$InstructionToJson(this);
  // }
}

@freezed
// @JsonSerializable(explicitToJson: true)
class InstructionGroup with _$InstructionGroup {
  factory InstructionGroup({
    required String name,
    required List<Instruction> instructions,
  }) = _InstructionGroup;

  factory InstructionGroup.fromJson(Map<String, dynamic> json) =>
      _$InstructionGroupFromJson(json);
}
