import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class SwingLensApp extends ConsumerWidget {
  const SwingLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SwingLens AI',
      debugShowCheckedModeBanner: false,
      theme: buildSwingLensTheme(),
      routerConfig: router,
    );
  }
}

