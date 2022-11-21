import 'package:equatable/equatable.dart';
import 'package:fauna_dart_driver/src/models/fauna_document.dart';

enum DocumentSnapshotAction {
  version,
  initial,
}

class DocumentSnapshot<T> {
  final DocumentSnapshotAction action;

  final T document;

  final T? prev;

  final T? diff;

  Map<String, dynamic> Function(T)? _deserializer;

  DocumentSnapshot({
    required this.action,
    required this.document,
    this.prev,
    this.diff,
    Map<String, dynamic> Function(T)? deserializer,
  }) : _deserializer = deserializer;

  static DocumentSnapshot<FaunaDocument> defaultSnapshot({
    required Map<String, dynamic> json,
    required DocumentSnapshotAction action,
  }) {
    return DocumentSnapshot<FaunaDocument>(
      action: action,
      document:
          FaunaDocument.fromJson(json["document"] as Map<String, dynamic>),
      prev: json["prev"] != null
          ? FaunaDocument.fromJson(json["prev"] as Map<String, dynamic>)
          : null,
      diff: json["diff"] != null
          ? FaunaDocument.fromJson(json["diff"] as Map<String, dynamic>)
          : null,
      deserializer: (doc) => doc.toJson(),
    );
  }

  static DocumentSnapshot<T> fromJson<T>(
    DocumentSnapshot<FaunaDocument> convertedDocument, {
    required T? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(T) deserializer,
  }) {
    T? data = serializer(convertedDocument.document);

    if (data == null) {
      throw ArgumentError('Could not deserialize document');
    }

    return DocumentSnapshot<T>(
      action: convertedDocument.action,
      document: data,
      prev: convertedDocument.prev != null
          ? serializer(convertedDocument.prev)
          : null,
      diff: convertedDocument.diff != null
          ? serializer(convertedDocument.diff)
          : null,
      deserializer: deserializer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': _fromDocumentChangeAction(action),
      'document': _deserializer!(document),
      'prev': prev != null ? _deserializer!(prev!) : null,
      'diff': diff != null ? _deserializer!(diff!) : null,
    };
  }

  static String _fromDocumentChangeAction(DocumentSnapshotAction action) {
    switch (action) {
      case DocumentSnapshotAction.initial:
        return 'initial';
      case DocumentSnapshotAction.version:
        return 'version';
    }
  }
}
