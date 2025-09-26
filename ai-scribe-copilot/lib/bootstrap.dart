import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/providers.dart';

Future<void> bootstrap() async {
  final container = ProviderContainer(overrides: await buildOverrides());
  runApp(UncontrolledProviderScope(
    container: container,
    child: const AiScribeApp(),
  ));
}
