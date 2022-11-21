import 'package:equatable/equatable.dart';
import 'package:faunadb_http/query.dart' as q;

mixin FaunaDataModel on Equatable {
  static const idField = "ID";
  static const createdAtField = "createdAt";
  static const lastTouchedField = "lastTouched";

  Map<String, dynamic> toJson();

  Map<String, dynamic> toFauna({
    /// Determines if the createdAt timestamp should be included in the payload
    bool createMode = false,

    /// Fields to be removed from the document before saving
    List<String> removeFields = const [],

    /// Fields to set to `Now()` in the final document
    List<String> timestampFields = const [],
  }) {
    var data = {
      ...toJson(),
      lastTouchedField: q.Now(),
    };

    if (createMode) {
      data[createdAtField] = q.Now();
    } else {
      data.remove(createdAtField);
    }
    data.remove(idField);

    for (var field in timestampFields) {
      data[field] = q.Now();
    }

    for (var field in removeFields) {
      data.remove(field);
    }

    return data;
  }
}
