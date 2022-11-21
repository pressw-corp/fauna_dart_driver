// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fauna_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FaunaDocument _$FaunaDocumentFromJson(Map<String, dynamic> json) =>
    FaunaDocument(
      ref: Reference.fromFaunaRef(json['ref'] as Map<String, dynamic>),
      timestamp: FaunaDocument._timestampFromJson(json['ts']),
      data: json['data'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$FaunaDocumentToJson(FaunaDocument instance) =>
    <String, dynamic>{
      'ref': Reference.toFaunaRef(instance.ref),
      'ts': FaunaDocument._timestampToJson(instance.timestamp),
      'data': instance.data,
    };
