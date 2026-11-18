import 'dart:async';
import 'dart:io';

import 'package:teen_patti_server/teen_patti_server.dart';

Future<void> main() async {
  final supabaseUrl = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final serviceRoleKey =
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';

  if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty) {
    stderr.writeln(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variable.',
    );
    exitCode = 2;
    return;
  }

  final workerId = Platform.environment['WORKER_ID']?.trim();
  final backend = SupabaseServerBackend(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
  );
  final transportFactory = SupabaseRealtimeTransportFactory(
    supabaseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
    workerKey: workerId ?? 'authoritative-worker',
  );
  final coordinator = WorkerCoordinator(
    backend: backend,
    transportFactory: transportFactory,
    workerId: workerId,
  );

  // Optional tiny HTTP health server for Fly.io / Cloud Run / Railway readiness.
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  HttpServer? healthServer;
  try {
    healthServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    unawaited(
      healthServer.forEach((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            '{"status":"ok","activeRooms":${coordinator.activeRooms.length}}',
          );
        await request.response.close();
      }),
    );
  } catch (err) {
    stderr.writeln('Health endpoint bind skipped ($err)');
  }

  await coordinator.start();
  stdout.writeln(
    'Teen Patti authoritative worker ${coordinator.workerId} started on port $port.',
  );

  final shutdown = Completer<void>();
  void triggerShutdown(ProcessSignal _) {
    if (!shutdown.isCompleted) shutdown.complete();
  }

  ProcessSignal.sigint.watch().listen(triggerShutdown);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(triggerShutdown);
  }

  await shutdown.future;
  await coordinator.stop();
  await healthServer?.close(force: true);
}
