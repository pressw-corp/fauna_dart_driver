import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:faunadb_http/query.dart';
import 'package:rxdart/subjects.dart';

import '../fauna_client.dart';
import '../streams/connection.dart';
import 'document_snapshot.dart';
import 'fauna_document.dart';

abstract class FaunaDocumentStream<T extends Object?> {
  FaunaClient get _faunaClient;
  Expr get _expression;
  Connection get _connection;

  Stream<DocumentSnapshot<T>> get stream;
  FaunaDocumentStream<U> withConverter<U>({
    required U? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(U? data) deserializer,
  });

  Future<void> close();
  void start();
}

class JsonFaunaDocumentStream extends FaunaDocumentStream<FaunaDocument?> {
  final BehaviorSubject<DocumentSnapshot<FaunaDocument>> _streamController =
      BehaviorSubject();
  final FaunaClient _faunaClient;
  final Expr _expression;
  Connection _connection;
  StreamSubscription? _subscription;
  String _state = "initial";

  JsonFaunaDocumentStream({
    required FaunaClient client,
    required Expr expression,
    Set<String>? fields,
  })  : _faunaClient = client,
        _expression = expression,
        _connection = Connection(
          client: client,
          expression: expression,
          options: ConnectionOptions(fields: fields),
        ) {
    // _faunaClient.addListener(_onStatusChange);
  }

  Future<void> close() {
    _state = "closed";
    _subscription?.cancel();
    return _streamController.close();
  }

  void start() async {
    if (_state != "initial") {
      throw Exception("Stream is already started.");
    }

    if (_streamController.isClosed) {
      throw Exception(
        'Can not start listening on an already closed connection',
      );
    }

    var res = await _faunaClient.docQuery(Get(_expression));

    if (res == null) {
      _streamController.addError(new Exception("No document found"));
      _streamController.close();
      return;
    }

    DocumentSnapshot<FaunaDocument> snapshot = DocumentSnapshot(
      document: res,
      action: DocumentSnapshotAction.initial,
    );

    _streamController.add(snapshot);

    _subscription = (await _connection.start()).listen((event) {
      Map<String, dynamic> json =
          Map.from(jsonDecode(utf8.decode(event)) as Map);

      if (json.containsKey("errors")) {
        _streamController.addError(new Exception(json["errors"].toString()));
        _streamController.close();
        return;
      }

      String type = json["type"] as String;

      if (type == "start") {
        return;
      } else if (type == "version") {
        Map<String, dynamic> data = json["event"] as Map<String, dynamic>;

        DocumentSnapshot<FaunaDocument>? snapshot;

        try {
          snapshot = DocumentSnapshot.defaultSnapshot(
            json: data,
            action: DocumentSnapshotAction.version,
          );
        } catch (e, stack) {
          _streamController.addError(e, stack);
          _streamController.close();
          rethrow;
        }

        _streamController.add(snapshot);
      }
    });
  }

  Stream<DocumentSnapshot<FaunaDocument>> get stream =>
      _streamController.stream;

  @override
  FaunaDocumentStream<U> withConverter<U>(
      {required U? Function(FaunaDocument? data) serializer,
      required Map<String, dynamic> Function(U? data) deserializer}) {
    if (_state != "initial") {
      throw Exception("Cannot add a converter to an already started stream");
    }

    return _FaunaDocumentStreamWithConverter<U>(
      original: this,
      serializer: serializer,
      deserializer: deserializer,
    );
  }
}

class _FaunaDocumentStreamWithConverter<T extends Object?>
    implements FaunaDocumentStream<T> {
  final BehaviorSubject<DocumentSnapshot<T>> _streamController =
      BehaviorSubject();
  final FaunaClient _faunaClient;
  final Expr _expression;
  Connection _connection;
  StreamSubscription? _subscription;
  T? Function(FaunaDocument? data) _serializer;
  Map<String, dynamic> Function(T? data) _deserializer;

  _FaunaDocumentStreamWithConverter({
    required FaunaDocumentStream original,
    required T? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(T? data) deserializer,
    Set<String>? fields,
  })  : _faunaClient = original._faunaClient,
        _expression = original._expression,
        _connection = original._connection,
        _serializer = serializer,
        _deserializer = deserializer;

  Future<void> close() {
    _subscription?.cancel();
    return _streamController.close();
  }

  void start() async {
    if (_streamController.isClosed) {
      throw Exception(
        'Can not start listening on an already closed connection',
      );
    }

    var res = await _faunaClient.docQuery(Get(_expression));

    if (res == null) {
      _streamController.addError(new Exception("No document found"));
      _streamController.close();
      return;
    }

    Map<String, dynamic> mappedData = {
      "document": Map.from(res.data),
    };

    DocumentSnapshot<T>? snapshot;

    try {
      snapshot = DocumentSnapshot.fromJson(
        DocumentSnapshot(
          document: res,
          action: DocumentSnapshotAction.initial,
        ),
        serializer: _serializer,
        deserializer: _deserializer,
      );
    } catch (e, stack) {
      _streamController.addError(e, stack);
      _streamController.close();
      rethrow;
    }

    if (_streamController.isClosed) {
      return;
    }

    _streamController.add(snapshot);

    _subscription = (await _connection.start()).listen((event) {
      String value = utf8.decode(event);
      Map<String, dynamic> json = jsonDecode(value) as Map<String, dynamic>;

      print("Receieved: $value");

      if (json.containsKey("errors")) {
        _streamController.addError(Exception(json["errors"].toString()));
        _streamController.close();
        return;
      }

      String type = json["type"] as String;

      if (type == "start") {
        return;
      } else if (type == "version") {
        Map<String, dynamic> data = json["event"] as Map<String, dynamic>;

        DocumentSnapshot<T>? snapshot;

        try {
          snapshot = DocumentSnapshot.fromJson(
            DocumentSnapshot.defaultSnapshot(
              json: data,
              action: DocumentSnapshotAction.version,
            ),
            serializer: _serializer,
            deserializer: _deserializer,
          );
        } catch (e, stack) {
          _streamController.addError(e, stack);
          _streamController.close();
          rethrow;
        }

        _streamController.add(snapshot);
      }
    });
  }

  Stream<DocumentSnapshot<T>> get stream => _streamController.stream;

  @override
  FaunaDocumentStream<U> withConverter<U>({
    required U? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(U? data) deserializer,
  }) {
    throw ArgumentError("Can not nest converters");
  }
}
