import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/router/deep_link_parser.dart';
import 'core/session/app_session_store.dart';
import 'core/session/local_storage_driver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppSessionStore.instance.configure(
    storageDriver: createPlatformStorageDriver(),
  );
  await AppSessionStore.instance.hydrate();
  final initialRoomCode = DeepLinkParser.extractRoomCodeFromUri(Uri.base);
  if (initialRoomCode != null) {
    AppSessionStore.instance.setPendingRoomCode(initialRoomCode);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const AceSocietyApp());
}
