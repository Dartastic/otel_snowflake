// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_snowflake/otel_snowflake.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_snowflake-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('SELECT records CLIENT span', () async {
    await tracedSnowflakeQuery<String>(
      statement: 'SELECT 1',
      account: 'abc-acme',
      warehouse: 'COMPUTE_WH',
      database: 'ANALYTICS',
      schema: 'PUBLIC',
      role: 'ANALYST',
      invoke: () async => const SnowflakeQueryResult(
        value: 'rows',
        queryId: '019aaa',
        rowCount: 1,
      ),
    );
    final a = attrsOf(spans.findSpanByName('snowflake SELECT')!);
    expect(a['db.system'], 'snowflake');
    expect(a['db.operation'], 'SELECT');
    expect(a['db.name'], 'ANALYTICS');
    expect(a['snowflake.account'], 'abc-acme');
    expect(a['snowflake.warehouse'], 'COMPUTE_WH');
    expect(a['snowflake.database'], 'ANALYTICS');
    expect(a['snowflake.schema'], 'PUBLIC');
    expect(a['snowflake.role'], 'ANALYST');
    expect(a['snowflake.query.id'], '019aaa');
    expect(a['db.row_count'], 1);
  });

  test('suppression skips spans', () async {
    await runWithoutSnowflakeInstrumentationAsync(() async {
      await tracedSnowflakeQuery<String>(
        statement: 'SELECT 1',
        invoke: () async => const SnowflakeQueryResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('snowflake '), isEmpty);
  });
}
