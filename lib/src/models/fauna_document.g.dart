// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fauna_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FaunaDocument _$FaunaDocumentFromJson(Map json) => FaunaDocument(
      ref: Reference.fromFaunaRef(json['ref'] as Map),
      timestamp: FaunaDocument._timestampFromJson(json['ts']),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );

Map<String, dynamic> _$FaunaDocumentToJson(FaunaDocument instance) =>
    <String, dynamic>{
      'ref': Reference.toFaunaRef(instance.ref),
      'ts': FaunaDocument._timestampToJson(instance.timestamp),
      'data': instance.data,
    };
