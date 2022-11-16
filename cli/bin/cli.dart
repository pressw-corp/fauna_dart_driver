import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fauna_dart_driver/fauna_dart_driver.dart';
import 'package:faunadb_http/query.dart';

const secret = 'secret';

void main(List<String> arguments) async {
  exitCode = 0; // presume success
  final parser = ArgParser()..addOption(secret, mandatory: true, abbr: 's');

  ArgResults argResults = parser.parse(arguments);

  if (!argResults.wasParsed(secret)) {
    print('Missing required option: $secret');
    exitCode = 64; // command line usage error
    return;
  }

  final parsedSecret = argResults[secret];

  final client = FaunaClient(secret: parsedSecret);

  final stream = client.stream(Documents(Collection('users')), {"document"});

  stream.start();
}
