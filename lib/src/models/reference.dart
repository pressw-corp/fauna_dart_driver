class Reference {
  final String id;
  final Reference? classRef;

  Reference({
    required this.id,
    this.classRef,
  });

  factory Reference.fromJson(Map<String, dynamic> json) {
    if (json.containsKey("@ref")) {
      json = json["@ref"] as Map<String, dynamic>;
    }

    Reference? classRef;

    if (json.containsKey("class")) {
      classRef = Reference.fromJson(json["class"] as Map<String, dynamic>);
    }

    return Reference(
      id: json['id'] as String,
      classRef: classRef,
    );
  }

  static Reference fromFaunaRef(Map<String, dynamic> json) {
    return Reference.fromJson(json);
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
}
