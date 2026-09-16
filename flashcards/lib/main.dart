import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/shared_preferences_provider.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/notification_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (kDebugMode) debugPrint(details.toString());
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
        return true;
      };

      if (!kDebugMode) {
        ErrorWidget.builder = (details) => const _FriendlyErrorWidget();
      }

      final prefs = await SharedPreferences.getInstance();

      runApp(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const FlashcardsApp(),
        ),
      );
    },
    (error, stack) {
      if (kDebugMode) debugPrint('Uncaught zone error: $error\n$stack');
    },
  );
}

class FlashcardsApp extends ConsumerStatefulWidget {
  const FlashcardsApp({super.key});

  @override
  ConsumerState<FlashcardsApp> createState() => _FlashcardsAppState();
}

class _FlashcardsAppState extends ConsumerState<FlashcardsApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await ref
        .read(notificationServiceProvider)
        .initialize(
          onTap: (_) {
            // Navigate to study tab when notification is tapped.
            ref.read(appRouterProvider).go('/study/all');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Deep Flashcard',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "This part of the app couldn't be displayed. "
                'Try going back and reopening it.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
