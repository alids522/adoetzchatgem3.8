import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AdoetzChat2App(),
    ),
  );
}

class AdoetzChat2App extends ConsumerWidget {
  const AdoetzChat2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Adoetz Chat 2',
      debugShowCheckedModeBanner: false,
      theme: AdoetzAppTheme.lightTheme,
      darkTheme: AdoetzAppTheme.darkTheme,
      themeMode: appState.themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Section 12.3 DoD #3: Support up to 200% system font scale gracefully without overflow crashes
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 2.0,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
