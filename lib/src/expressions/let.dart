import 'package:faunadb_http/query.dart';
import 'package:json_annotation/json_annotation.dart';

part 'let.g.dart';

@JsonSerializable()
class Let extends Expr {
  @JsonKey(name: 'let', toJson: _bindingsToJson, fromJson: _bindingsFromJson)
  final Map<String, dynamic> bindings;

  @JsonKey(name: 'in')
  final Expr in_;

  Let(this.bindings, this.in_);

  factory Let.fromJson(Map<String, dynamic> json) => _$LetFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$LetToJson(this);

  static List<Map<String, dynamic>> _bindingsToJson(Map<String, dynamic> data) {
    return data.entries.map((e) => {e.key: e.value}).toList();
  }

  static Map<String, dynamic> _bindingsFromJson(
      List<Map<String, dynamic>> data) {
    return data.fold({}, (prev, e) => prev..addAll(e));
  }
}
