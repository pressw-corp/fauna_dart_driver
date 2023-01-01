import 'dart:convert';

import 'package:fauna_dart_driver/fauna_dart_driver.dart';
import 'package:fauna_dart_driver/src/models/document_snapshot.dart';
import 'package:fauna_dart_driver/src/models/fauna_document.dart';
import 'package:fauna_dart_driver/src/models/fauna_set_stream.dart';
import 'package:faunadb_http/query.dart';
// import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:io';

import 'package:synchronized/synchronized.dart';

import 'models/fauna_stream.dart';

class FaunaClient {
  late final String _baseUrl;

  final String _secret;
  final String _domain;
  final String _scheme;
  late final int? _port;
  late String _authHeader;
  final int _timeout;
  final int _connectionSize;
  final int _poolMaxSize;
  final String? _endpoint;
  late _LastTxnTime _lastTransactionTime;
  late int? _queryTimeoutMs;
  late _Counter _counter;
  late Client _client;
  late final Map<String, String> baseHeaders;
  late final Uri uri;

  String get baseUrl => "$_domain";
  int? get port => _port;
  int? get queryTimeoutMs => _queryTimeoutMs;
  bool _isClosed = false;

  bool get isClosed => _isClosed;

  Map<String, String> getAuthHeader() => {"Authorization": _authHeader};

  FaunaClient({
    required String secret,
    String domain = "db.us.fauna.com",
    String scheme = "https",
    int? port,
    int timeout = 60,
    // observer=None,
    int poolConnections = 10,
    int poolMaxsize = 10,
    String? endpoint,
    Client? client,
    _LastTxnTime? lastTransactionTime,
    int? queryTimeoutMs,
    _Counter? counter,
  })  : _secret = secret,
        _domain = domain,
        _scheme = scheme,
        _timeout = timeout,
        _connectionSize = poolConnections,
        _poolMaxSize = poolMaxsize,
        _endpoint = endpoint {
    _lastTransactionTime =
        lastTransactionTime ?? _LastTxnTime.create(value: null);
    _queryTimeoutMs = queryTimeoutMs;
    _port = port ?? (scheme == "https" ? 443 : 80);

    baseHeaders = {
      "Keep-Alive": "timeout=5",
      "Accept-Encoding": "gzip",
      "Content-Type": "application/json;charset=utf-8",
      "X-Fauna-Driver": "dart",
      "X-FaunaDB-API-Version": "4",
      "Content-type": "application/json; charset=utf-8",
      'X-Driver-Env': 'driver=dart; runtime=dart env=unknown; os=unknown',
      'Connection': 'keep-alive',
      'Accept': '*/*',
      'User-Agent': 'dart-http2/2.12.0',
    };

    print(_secret);

    _authHeader = "Bearer $_secret";
    String constructedUrl = "$_scheme://$_domain:$_port";

    if (endpoint != null) {
      _baseUrl = _normalizeEndpoint(endpoint);
    } else {
      _baseUrl = constructedUrl;
    }

    uri = Uri.parse(_baseUrl);

    _counter = counter ?? _Counter.create(value: 1);
    _client = client ?? Client();
  }

  Future<FaunaClient> newSessionClient(String secret) async {
    if (await _counter.getAndIncrement() > 0) {
      return FaunaClient(
        secret: secret,
        domain: _domain,
        scheme: _scheme,
        port: _port,
        timeout: _timeout,
        poolConnections: _connectionSize,
        poolMaxsize: _poolMaxSize,
        endpoint: _endpoint,
        client: _client,
        lastTransactionTime: _lastTransactionTime,
        queryTimeoutMs: _queryTimeoutMs,
        counter: _counter,
      );
    }

    throw Exception("Cannot create a new fauna client from a closed client");
  }

  Future<void> syncLastTransactionTime(DateTime newTime) {
    return _lastTransactionTime.update(newTime);
  }

  Future<DateTime?> getLastTransactionTime() {
    return _lastTransactionTime.time();
  }

  int? getQueryTimeoutMs() {
    return _queryTimeoutMs;
  }

  String _normalizeEndpoint(String endpoint) {
    return endpoint.replaceAll(r'/\\', '');
  }

  Future<void> close() async {
    int count = await _counter.decrement();
    if (count == 0) {
      print('closing client');
      _isClosed = true;
      // notifyListeners();
    }
  }

  void setSecret(String secret) {
    _authHeader = "Bearer $_secret";
  }

  Future<FaunaDocument?> docQuery(Expr expression) {
    return _execute(
      action: "POST",
      path: "",
      data: expression,
      withTransactionTime: true,
      transformer: (data) {
        return FaunaDocument.fromFauna(
            data["resource"] as Map<String, dynamic>);
      },
    );
  }

  Future<Object?> query(Expr expression) {
    return _execute(
      action: "POST",
      path: "",
      data: expression,
      withTransactionTime: false,
      transformer: (data) {
        return data["resource"] as Object?;
      },
    );
  }

  Future<T?> _execute<T>({
    required String action,
    required String path,
    required T? Function(Map<String, dynamic> data) transformer,
    Expr? data,
    Map<String, String?>? query,
    int? queryTimeoutMs,
    bool withTransactionTime = false,
  }) async {
    // final response = await _pool.withResource(() async {
    //   final request = await _createRequest(action, path, data, query, transactionTime, queryTimeoutMs);
    //   return await request.close();
    // });
    // return await _parseResponse(response);
    Map<String, String> filteredQuery = {};
    for (MapEntry<String, String?> entry in (query ?? {}).entries) {
      if (entry.value != null) {
        filteredQuery[entry.key] = entry.value!;
      }
    }

    Map<String, String> headers = {};
    headers.addAll(baseHeaders);
    if (withTransactionTime) {
      headers.addAll(await _lastTransactionTime.requestHeader());
    }

    if (queryTimeoutMs != null) {
      headers['X-Query-Timeout'] = queryTimeoutMs.toString();
    }

    headers['Authorization'] = _authHeader;
    headers['X-Fauna-Driver'] = "dart";
    headers['X-Driver-Env'] =
        'driver=dart; runtime=dart env=unknown; os=unknown';

    DateTime? startTime = DateTime.now();
    Response response = await _performRequest("POST", path, data, headers);
    DateTime? endTime = DateTime.now();

    if (withTransactionTime) {
      if (response.headers["X-Txn-Time"] != null) {
        DateTime newTime = DateTime.fromMillisecondsSinceEpoch(
            int.parse(response.headers["X-Txn-Time"]!));
        _lastTransactionTime.update(newTime);
      }
    }

    if (response.statusCode == 200) {
      return transformer(jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      if (response.statusCode == 401) {
        throw AuthorizationException(
          "Unauthorized",
          response.statusCode,
          jsonDecode(response.body),
        );
      } else {
        throw Exception("Error: ${response.statusCode} ${response.body}");
      }
    }

    //  String response_raw = response.
    //     response_content = parse_json_or_none(response_raw)
  }

  FaunaDocumentStream<FaunaDocument?> docStream(
    Expr expression,
    Set<String>? fields,
  ) {
    return JsonFaunaDocumentStream(
      client: this,
      expression: expression,
      fields: fields,
    );
  }

  FaunaSetStream<FaunaDocument> setStream(
    Expr expression,
    Set<String>? fields,
  ) {
    return JsonFaunaSetStream(
      client: this,
      expression: expression,
      fields: fields,
    );
  }

  FaunaStream stream(Expr expression, Set<String>? fields) {
    return FaunaStream(
      client: this,
      expression: expression,
      fields: fields,
    );
  }

  Future<Response> _performRequest(
    String action,
    String path,
    Expr? data,
    Map<String, String> headers,
  ) {
    Uri uri = Uri.parse("$_baseUrl/$path");

    String? encoded;
    if (data != null) {
      encoded = jsonEncode(data.toJson());
    }

    if (action == "POST") {
      return _client
          .post(
            uri,
            headers: headers,
            body: encoded,
          )
          .timeout(Duration(seconds: _timeout));
    } else if (action == "GET") {
      return _client.get(uri, headers: headers);
    }

    throw Exception("Unsupported action: $action");
  }
}

class _Counter {
  int _value;
  final Lock lock = Lock();

  _Counter.create({
    required int value,
  }) : _value = value;

  Future<int> getAndIncrement() {
    return lock.synchronized(() {
      int counter = _value;
      _value += 1;
      return counter;
    });
  }

  Future<int> get() {
    return lock.synchronized(() {
      return _value;
    });
  }

  Future<int> decrement() {
    return lock.synchronized(() {
      _value -= 1;
      return _value;
    });
  }
}

class _LastTxnTime {
  DateTime? _value;
  final Lock lock = Lock();

  _LastTxnTime.create({
    required DateTime? value,
  }) : _value = value;

  Future<DateTime?> time() {
    return lock.synchronized(() {
      return _value;
    });
  }

  Future<Map<String, String>> requestHeader() {
    return lock.synchronized(() {
      if (_value == null) {
        return {};
      }

      return {
        "X-Last-Seen-Txn": _value!.millisecondsSinceEpoch.toString(),
      };
    });
  }

  Future<void> update(DateTime? value) {
    return lock.synchronized(() {
      if (_value == null) {
        _value = value;
      } else if (value != null && value.isAfter(_value!)) {
        _value = value;
      }
    });
  }
}

class AuthorizationException {
  final String message;
  final Map<String, dynamic> body;
  final int statusCode;

  AuthorizationException(this.message, this.statusCode, this.body);
}
