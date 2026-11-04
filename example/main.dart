// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_snowflake/otel_snowflake.dart';

/// Traces Snowflake calls with OpenTelemetry.
///
/// `otel_snowflake` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Snowflake call in
/// [tracedSnowflakeQuery]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'snowflake-example');

  // Wraps a Snowflake SQL query in a CLIENT span.
  final snowflakeQueryId = await tracedSnowflakeQuery<String>(
    statement: 'active',
    account: 'example',
    warehouse: 'example',
    database: 'example',
    schema: 'example',
    role: 'example',
    invoke: () async {
      // Make the Snowflake call here, then report what it returned.
      const id = 'snowflake_8f3a2c';
      return const SnowflakeQueryResult(
          value: id, queryId: 'query_8f3a2c', rowCount: 3);
    },
  );
  OTelLog.info('tracedSnowflakeQuery returned $snowflakeQueryId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSnowflakeInstrumentationAsync.
  await runWithoutSnowflakeInstrumentationAsync(
    () => tracedSnowflakeQuery<String>(
      statement: 'active',
      account: 'example',
      warehouse: 'example',
      database: 'example',
      schema: 'example',
      role: 'example',
      invoke: () async {
        const id = 'snowflake_8f3a2c';
        return const SnowflakeQueryResult(
            value: id, queryId: 'query_8f3a2c', rowCount: 3);
      },
    ),
  );

  await OTel.shutdown();
}
