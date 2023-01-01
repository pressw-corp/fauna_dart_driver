import 'dart:async';
import 'dart:convert';

import 'package:faunadb_http/query.dart';

import '../fauna_client.dart';
import '../streams/connection.dart';

class FaunaStream {
  final StreamController<dynamic> _streamController =
      StreamController.broadcast();
  final FaunaClient _faunaClient;
  final Expr _expression;
  Connection _connection;
  Stream<dynamic>? _stream;
  StreamSubscription<dynamic>? _subscription;

  FaunaStream({
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

  void _onStatusChange() {
    if (_faunaClient.isClosed) {
      close();
    }
  }

  Future<void> close() {
    _subscription?.cancel();
    return _streamController.close();
  }

  void start() async {
    var res = await _faunaClient.docQuery(_expression);

    _subscription = (await _connection.start()).listen((event) {
      _streamController.add(utf8.decode(event));
    });
  }

  Stream get stream => _streamController.stream;
}
