import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:faunadb_http/query.dart';
import 'package:http/http.dart';
import "package:http2/http2.dart";

import '../fauna_client.dart';

const VALID_FIELDS = {"diff", "prev", "document", "action", "index"};

class ConnectionOptions {
  Set<String>? fields;

  ConnectionOptions({this.fields});
}

class Connection {
  final FaunaClient _faunaClient;
  final Expr _query;
  String _state = 'idle';
  final Set<String> _fields;
  late String _data;
  Client? _client;

  Connection({
    required FaunaClient client,
    required Expr expression,
    ConnectionOptions? options,
  })  : _faunaClient = client,
        _query = expression,
        _fields = options?.fields ?? {} {
    Set<String> union = _fields.union(VALID_FIELDS);
    // if (!setEquals(union, VALID_FIELDS)) {
    //   throw Exception("Valid fields options are %s, provided %s.");
    // }
    _data = jsonEncode(expression.toJson());
  }

  Future<void> close() async {
    if (_client == null || _state == "closed") {
      throw Exception('Tried to close an already closed steam');
    }
    _client?.close();
    _state = "closed";
  }

  Future<Stream> start() async {
    if (_state != 'idle') {
      throw Exception("Connection is already started.");
    }

    try {
      _state = 'connecting';
      Map<String, String> headers = Map.from(_faunaClient.baseHeaders);
      headers.addAll(_faunaClient.getAuthHeader());

      if (_faunaClient.queryTimeoutMs != null) {
        headers["X-Query-Timeout"] = _faunaClient.queryTimeoutMs.toString();
      }

      DateTime? lastTransactionTime =
          await _faunaClient.getLastTransactionTime();

      if (lastTransactionTime != null) {
        headers["X-Last-Seen-Txn"] =
            lastTransactionTime.millisecondsSinceEpoch.toString();
      } else {
        headers["X-Last-Seen-Txn"] =
            DateTime.now().millisecondsSinceEpoch.toString();
      }

      DateTime startTime = DateTime.now();
      String urlParams = '';
      if (_fields.isNotEmpty) {
        urlParams =
            '?${Uri.encodeComponent("fields")}=${Uri.encodeComponent(_fields.join(","))}';
      }

      var client = Client();

      Map<String, String> query = {};

      if (_fields.isNotEmpty) {
        query["fields"] = Uri.encodeComponent(_fields.join(","));
      }

      var request = Request(
        "POST",
        Uri.https(_faunaClient.baseUrl, "/stream", query),
      );

      request.body = _data;

      for (var entry in headers.entries) {
        request.headers[entry.key] = entry.value;
      }

      // request.headers[':method'] = "POST";
      // request.headers[':path'] = "/stream$urlParams";
      // request.headers[":scheme"] = _faunaClient.uri.scheme;
      // request.headers[":authority"] = _faunaClient.uri.host;

      StreamedResponse response = await client.send(
        Request(
          "POST",
          Uri.https(_faunaClient.baseUrl, "/stream$urlParams"),
        ),
      );

      print(response.statusCode);
      print(response.reasonPhrase);

      return response.stream.map((event) {
        print(event);
        return event;
      });
    } catch (e, stack) {
      print(e);
      print(stack);
      rethrow;
    }
  }
}
