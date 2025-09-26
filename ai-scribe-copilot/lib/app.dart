import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'shared/providers.dart';
import 'utils/theme.dart';

class AiScribeApp extends ConsumerWidget {
  const AiScribeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'AI Scribe Copilot',
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
