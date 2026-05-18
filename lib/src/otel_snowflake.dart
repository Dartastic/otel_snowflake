// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_snowflake_suppression.dart';

const _tracerName = 'dartastic_otel_libs_snowflake';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedSnowflakeQuery` callback.
class SnowflakeQueryResult<T> {
  const SnowflakeQueryResult({
    required this.value,
    this.queryId,
    this.rowCount,
  });
  final T value;
  final String? queryId;
  final int? rowCount;
}

const _maxStatementLength = 1024;
String _truncate(String s) =>
    s.length <= _maxStatementLength ? s : s.substring(0, _maxStatementLength);

/// Wraps a Snowflake SQL query in a CLIENT span.
Future<T> tracedSnowflakeQuery<T>({
  required String statement,
  required Future<SnowflakeQueryResult<T>> Function() invoke,
  String? account,
  String? warehouse,
  String? database,
  String? schema,
  String? role,
}) async {
  if (snowflakeInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': 'snowflake',
    'db.operation': _operationFromStatement(statement) ?? 'query',
    'db.statement': _truncate(statement),
  };
  if (account != null) m['snowflake.account'] = account;
  if (warehouse != null) m['snowflake.warehouse'] = warehouse;
  if (database != null) {
    m['db.name'] = database;
    m['snowflake.database'] = database;
  }
  if (schema != null) m['snowflake.schema'] = schema;
  if (role != null) m['snowflake.role'] = role;

  final span = _tracer().startSpan(
    'snowflake ${m['db.operation']}',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.queryId != null) {
      extras.add(OTel.attributeString('snowflake.query.id', r.queryId!));
    }
    if (r.rowCount != null) {
      extras.add(OTel.attributeInt('db.row_count', r.rowCount!));
    }
    if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

String? _operationFromStatement(String statement) {
  final trimmed = statement.trimLeft();
  if (trimmed.isEmpty) return null;
  final first = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
  const known = {
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
    'BEGIN',
    'COMMIT',
    'ROLLBACK',
    'CREATE',
    'ALTER',
    'DROP',
    'TRUNCATE',
    'COPY',
    'MERGE',
    'PUT',
    'GET',
    'WITH',
    'CALL',
    'SHOW',
  };
  return known.contains(first) ? first : null;
}
