import 'package:faunadb_http/query.dart' as q;

class Reference {
  final String id;
  final Reference? classRef;

  Reference({
    required this.id,
    this.classRef,
  });

  factory Reference.fromJson(Map<dynamic, dynamic> json) {
    if (json.containsKey("@ref")) {
      json = (json["@ref"] as Map).cast<String, dynamic>();
    } else if (json.containsKey("value")) {
      json = (json["value"] as Map).cast<String, dynamic>();
    }

    Reference? classRef;

    if (json.containsKey("class")) {
      classRef = Reference.fromJson(json["class"] as Map<String, dynamic>);
    } else if (json.containsKey("collection")) {
      classRef = Reference.fromJson(
          (json["collection"] as Map).cast<String, dynamic>());
    }

    return Reference(
      id: json['id'] as String,
      classRef: classRef,
    );
  }

  static Reference fromFaunaRef(Map<dynamic, dynamic> json) {
    return Reference.fromJson(json.cast<String, dynamic>());
  }

  static Map<String, dynamic> toFaunaRef(Reference ref) {
    return ref.toJson();
  }

  Map<String, dynamic> toJson() {
    return {
      '@ref': {
        'id': id,
        'class': classRef?.toJson(),
      },
    };
  }

  q.Expr toExpr() {
    if (classRef != null) {
      return q.Ref(q.Collection(classRef!.id), id);
    } else {
      // TODO: This is incorrect
      return q.Ref(q.Collection(id), id);
    }
  }
}
