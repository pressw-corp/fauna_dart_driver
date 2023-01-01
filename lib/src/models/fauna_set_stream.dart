import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:fauna_dart_driver/fauna_dart_driver.dart';
import 'package:faunadb_http/query.dart' as q;
import 'package:rxdart/subjects.dart';

import '../fauna_client.dart';
import '../streams/connection.dart';
import 'document_snapshot.dart';
import 'fauna_document.dart';
import 'reference.dart';

abstract class FaunaSetStream<T extends Object?> {
  FaunaClient get _faunaClient;
  q.Expr get _expression;
  Connection get _connection;

  Stream<List<DocumentSnapshot<T>>> get stream;
  FaunaSetStream<U> withConverter<U>({
    required U? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(U? data) deserializer,
    String? refField,
  });

  Future<void> close();
  void start();
}

class JsonFaunaSetStream extends FaunaSetStream<FaunaDocument> {
  final BehaviorSubject<List<DocumentSnapshot<FaunaDocument>>>
      _streamController = BehaviorSubject();

  @override
  final FaunaClient _faunaClient;

  @override
  final q.Expr _expression;

  @override
  final Connection _connection;

  final String? _refField;

  StreamSubscription<List<int>>? _subscription;

  List<dynamic> _buffer = [];

  bool _buffering = true;

  String _state = "initial";

  JsonFaunaSetStream({
    required FaunaClient client,
    required q.Expr expression,
    Set<String>? fields,
    String? refField,
  })  : _faunaClient = client,
        _expression = expression,
        _refField = refField,
        _connection = Connection(
          client: client,
          expression: expression,
          options: ConnectionOptions(fields: fields),
        ) {
    // _faunaClient.addListener(_onStatusChange);
  }

  @override
  Future<void> close() {
    _state = "closed";
    _subscription?.cancel();
    return _streamController.close();
  }

  @override
  void start() async {
    if (_state != "initial") {
      throw Exception("Stream is already started.");
    }

    if (_streamController.isClosed) {
      throw Exception(
        'Can not start listening on an already closed connection',
      );
    }

    if (!kSupportsHttp2) {
      await _initialQuery();
      return;
    }

    _subscription = (await _connection.start()).listen((event) async {
      Map<String, dynamic> json =
          Map.from(jsonDecode(utf8.decode(event)) as Map);

      if (json.containsKey("errors")) {
        _streamController.addError(Exception(json["errors"].toString()));
        _streamController.close();
        return;
      }

      String type = json["type"] as String;

      if (type == "start") {
        await _initialQuery();
        return;
      } else if (type == "set") {
        Map<String, dynamic> data = json["event"] as Map<String, dynamic>;
        String action = data["action"] as String;

        switch (action) {
          case "add":
            Map<String, dynamic> documentRefData =
                (data["document"] as Map).cast<String, dynamic>();

            Reference ref = Reference.fromJson(
                documentRefData["ref"] as Map<String, dynamic>);

            var doc = await _faunaClient.docQuery(
              q.Get(
                q.Ref(
                  q.Collection(ref.classRef!.id),
                  ref.id,
                ),
              ),
            );

            if (doc == null) {
              _streamController.addError(
                  Exception("Failed to pull additional document: $ref"));
              _streamController.close();
              return;
            }

            var value = _streamController.valueOrNull ?? [];

            var snapshot = DocumentSnapshot(
              action: DocumentSnapshotAction.initial,
              document: doc,
            );

            if (_refField != null) {
              var refField = snapshot.document.data[_refField];

              Reference ref = Reference.fromJson(
                (refField as Map<dynamic, dynamic>).cast<String, dynamic>(),
              );

              var pulledDocument = await _faunaClient.docQuery(
                q.Get(
                  q.Ref(
                    q.Collection(ref.classRef!.id),
                    ref.id,
                  ),
                ),
              );

              if (pulledDocument == null) {
                _streamController.addError(
                    Exception("Failed to pull additional document: $ref"));
                _streamController.close();
                return;
              }

              snapshot = DocumentSnapshot(
                action: DocumentSnapshotAction.initial,
                document: pulledDocument,
              );

              value.add(snapshot);
            } else {
              value.add(snapshot);
            }

            _streamController.add(value);

            break;
          case "remove":
            break;
        }
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

        _streamController.add([snapshot]);
      }
    });
  }

  Future<void> _initialQuery() async {
    var res = await _faunaClient.query(q.Map_(
      q.Paginate(_expression),
      q.Lambda(
        'ref',
        q.Get(
          q.Var('ref'),
        ),
      ),
    ));

    if (res == null) {
      _streamController.addError(Exception("Failed to pull documents"));
      _streamController.close();
      return;
    }

    Map<String, dynamic> dataMap = Map.from(res as Map);

    var docs = (dataMap["data"] as List)
        .map(
          (e) => DocumentSnapshot(
            action: DocumentSnapshotAction.initial,
            document: FaunaDocument.fromJson(e as Map<String, dynamic>),
          ),
        )
        .toList();

    _streamController.add(docs);
  }

  @override
  Stream<List<DocumentSnapshot<FaunaDocument>>> get stream =>
      _streamController.stream;

  @override
  FaunaSetStream<U> withConverter<U>({
    required U? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(U? data) deserializer,
    String? refField,
  }) {
    if (_state != "initial") {
      throw Exception("Cannot add a converter to an already started stream");
    }

    return _FaunaSetStreamWithConverter<U>(
      original: this,
      serializer: serializer,
      deserializer: deserializer,
      refField: refField,
    );
  }
}

class _FaunaSetStreamWithConverter<T extends Object?>
    implements FaunaSetStream<T> {
  final BehaviorSubject<List<DocumentSnapshot<T>>> _streamController =
      BehaviorSubject();

  @override
  final FaunaClient _faunaClient;

  @override
  final q.Expr _expression;

  @override
  final String? _refField;

  @override
  final Connection _connection;

  StreamSubscription<dynamic>? _subscription;

  final T? Function(FaunaDocument? data) _serializer;
  final Map<String, dynamic> Function(T? data) _deserializer;

  _FaunaSetStreamWithConverter({
    required FaunaSetStream original,
    required T? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(T? data) deserializer,
    Set<String>? fields,
    String? refField,
  })  : _faunaClient = original._faunaClient,
        _expression = original._expression,
        _connection = original._connection,
        _serializer = serializer,
        _deserializer = deserializer,
        _refField = refField;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return _streamController.close();
  }

  @override
  void start() async {
    if (_streamController.isClosed) {
      throw Exception(
        'Can not start listening on an already closed connection',
      );
    }

    if (!kSupportsHttp2) {
      await _initialQuery();
      return;
    }

    _subscription = (await _connection.start()).listen((event) async {
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
        await _initialQuery();
        return;
      } else if (type == "set") {
        Map<String, dynamic> data = json["event"] as Map<String, dynamic>;
        String action = data["action"] as String;

        switch (action) {
          case "add":
            Map<String, dynamic> documentRefData =
                (data["document"] as Map).cast<String, dynamic>();

            Reference ref = Reference.fromJson(
                documentRefData["ref"] as Map<String, dynamic>);

            var doc = await _faunaClient.docQuery(
              q.Get(
                q.Ref(
                  q.Collection(ref.classRef!.id),
                  ref.id,
                ),
              ),
            );

            if (doc == null) {
              _streamController.addError(
                  Exception("Failed to pull additional document: $ref"));
              _streamController.close();
              return;
            }

            var value = _streamController.valueOrNull ?? [];

            DocumentSnapshot<FaunaDocument> snapshot = DocumentSnapshot(
              action: DocumentSnapshotAction.initial,
              document: doc,
            );

            if (_refField != null) {
              var refField = snapshot.document.data[_refField];

              Reference ref = Reference.fromJson(
                (refField as Map<dynamic, dynamic>).cast<String, dynamic>(),
              );

              var pulledDocument = await _faunaClient.docQuery(
                q.Get(
                  q.Ref(
                    q.Collection(ref.classRef!.id),
                    ref.id,
                  ),
                ),
              );

              if (pulledDocument == null) {
                _streamController.addError(
                    Exception("Failed to pull additional document: $ref"));
                _streamController.close();
                return;
              }

              snapshot = DocumentSnapshot(
                action: DocumentSnapshotAction.initial,
                document: pulledDocument,
              );
            }

            value.add(
              DocumentSnapshot.fromJson<T>(
                snapshot,
                serializer: _serializer,
                deserializer: _deserializer,
              ),
            );

            if (_streamController.isClosed) {
              return;
            }

            _streamController.add(value);

            break;
          case "remove":
            break;
        }
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

        _streamController.add([snapshot]);
      }
    });
  }

  Future<void> _initialQuery() async {
    var res = await _faunaClient.query(q.Map_(
      q.Paginate(_expression),
      q.Lambda(
        'ref',
        q.Get(
          q.Var('ref'),
        ),
      ),
    ));

    if (res == null) {
      _streamController.addError(Exception("Failed to pull documents"));
      _streamController.close();
      return;
    }

    Map<String, dynamic> dataMap = Map.from(res as Map);

    var docs = (dataMap["data"] as List)
        .map(
          (e) => DocumentSnapshot(
            action: DocumentSnapshotAction.initial,
            document: FaunaDocument.fromJson(e as Map<String, dynamic>),
          ),
        )
        .toList();

    List<DocumentSnapshot<T>> mappedDocs = docs
        .map(
          (e) => DocumentSnapshot.fromJson<T>(
            e,
            serializer: _serializer,
            deserializer: _deserializer,
          ),
        )
        .toList();

    _streamController.add(mappedDocs);
  }

  Stream<List<DocumentSnapshot<T>>> get stream => _streamController.stream;

  @override
  FaunaSetStream<U> withConverter<U>({
    required U? Function(FaunaDocument? data) serializer,
    required Map<String, dynamic> Function(U? data) deserializer,
    Set<String>? fields,
    String? refField,
  }) {
    throw ArgumentError("Can not nest converters");
  }
}
