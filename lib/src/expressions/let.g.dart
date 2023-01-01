// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'let.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Let _$LetFromJson(Map json) => Let(
      Let._bindingsFromJson(json['let'] as List<Map<String, dynamic>>),
      Expr.fromJson(Map<String, dynamic>.from(json['in'] as Map)),
    );

Map<String, dynamic> _$LetToJson(Let instance) => <String, dynamic>{
      'let': Let._bindingsToJson(instance.bindings),
      'in': instance.in_,
    };
