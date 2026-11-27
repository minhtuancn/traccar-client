import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/push_service.dart';
import 'package:traccar_client/quick_actions.dart';

import 'configuration_service.dart';
import 'geolocation_service.dart';
import 'l10n/app_localizations.dart';
import 'main_screen.dart';
import 'managed_config_service.dart';
import 'preferences.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();
final mainScreenKey = GlobalKey<MainScreenState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupGate());
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<void> _startup = _initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
          return const MainApp();
        }
        return MaterialApp(
          title: 'ZalGps',
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('ZalGps')),
            body: Builder(builder: (context) {
              final strings = AppLocalizations.of(context)!;
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!snapshot.hasError) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(snapshot.hasError ? strings.startupFailed : strings.startupLoading),
                  ],
                ),
              ));
            }),
          ),
        );
      },
    );
  }
}

Future<void> _initialize() async {
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await Preferences.init();
  await GeolocationService.init(Preferences.buildConfig());
  await PasswordService.migrate();
  await ManagedConfigService.init();
  unawaited(PushService.init().catchError((Object error, StackTrace stack) {
    debugPrint('ZalGps notification initialization failed');
  }));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  RateMyApp rateMyApp = RateMyApp(minDays: 7, minLaunches: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLinks();
      await rateMyApp.init();
      final dialogContext = navigatorKey.currentContext;
      if (dialogContext != null && dialogContext.mounted && rateMyApp.shouldOpenDialog) {
        await rateMyApp.showRateDialog(dialogContext);
      }
    });
  }

  Future<void> _initLinks() async {
    AppLinks().uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.host == 'action') {
      try {
        switch (uri.pathSegments.firstOrNull) {
          case 'start':
            await GeolocationService.start();
          case 'stop':
            await GeolocationService.stop();
        }
      } on PlatformException {
        // permission denied or startup error
      }
      return;
    }
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.configurationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.okButton),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ConfigurationService.applyUri(uri);
      mainScreenKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZalGps',
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: Stack(
        children: [
          const QuickActionsInitializer(),
          MainScreen(key: mainScreenKey),
        ],
      ),
    );
  }
}
