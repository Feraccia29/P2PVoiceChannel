import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/lobby_provider.dart';
import 'screens/lobby_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/window_title_bar.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (isDesktop) {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(400, 300),
        center: true,
        backgroundColor: AppTheme.backgroundDark,
        titleBarStyle: TitleBarStyle.hidden,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
      return true; // Previene il crash dell'app
    };

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Zone error: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LobbyProvider(),
      child: MaterialApp(
        title: 'VoIP P2P',
        theme: AppTheme.darkTheme,
        home: const WithForegroundTask(
          child: LobbyScreen(),
        ),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (!isDesktop) return child!;
          return Column(
            children: [
              const WindowTitleBar(),
              Expanded(child: child!),
            ],
          );
        },
      ),
    );
  }
}
