import 'dart:async';

import 'package:faunadb_http/query.dart';

import '../fauna_client.dart';
import '../streams/connection.dart';

class FaunaStream {
  final StreamController _streamController = StreamController.broadcast();
  final FaunaClient _faunaClient;
  final Expr _expression;
  Connection _connection;
  Stream? _stream;
  StreamSubscription? _subscription;

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
    // _faunaClient.removeListener(_onStatusChange);
    _subscription?.cancel();
    return _streamController.close();
  }

  void start() async {
    var res = await _faunaClient.query(Documents(Collection("users")));

    _stream = await _connection.start();

    // _subscription = _stream!.incomingMessages.listen((event) {
    //   print(event);
    //   _streamController.add(event);
    // });
  }

  Stream get stream => _streamController.stream;
}
