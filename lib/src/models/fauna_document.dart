import 'package:equatable/equatable.dart';
import 'package:faunadb_http/query.dart';
import 'package:json_annotation/json_annotation.dart';

import 'reference.dart';

part 'fauna_document.g.dart';

@JsonSerializable(explicitToJson: true)
class FaunaDocument extends Equatable {
  @override
  List<Object?> get props => [ref.id, timestamp];

  @JsonKey(
    name: 'ref',
    fromJson: Reference.fromFaunaRef,
    toJson: Reference.toFaunaRef,
  )
  final Reference ref;

  @JsonKey(name: 'ts', fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime timestamp;

  @JsonKey(name: 'data')
  final Map<String, dynamic> data;

  FaunaDocument({
    required this.ref,
    required this.timestamp,
    required this.data,
  });

  factory FaunaDocument.fromFauna(Map<String, dynamic> json) {
    if (json.containsKey("@ref")) {
      json["ref"] = json["@ref"];
    }

    return FaunaDocument.fromJson(json);
  }

  factory FaunaDocument.fromJson(Map<String, dynamic> json) =>
      _$FaunaDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$FaunaDocumentToJson(this);

  static DateTime _timestampFromJson(dynamic timestamp) {
    if (timestamp is int) {
      return DateTime.fromMicrosecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is DateTime) {
      return timestamp.toLocal();
    } else if (timestamp is Map) {
      return DateTime.parse(timestamp["value"] as String);
    } else {
      throw ArgumentError.value(timestamp, 'timestamp');
    }
  }

  static dynamic _timestampToJson(DateTime timestamp) {
    return timestamp.microsecondsSinceEpoch;
  }
}
