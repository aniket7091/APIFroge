import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/collection_service.dart';
import 'services/history_service.dart';
import 'services/proxy_service.dart';
import 'services/request_service.dart';
import 'utils/storage_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageUtils.init();
  final savedMode = StorageUtils.getThemeMode();
  runApp(APIForgeApp(initialThemeMode: savedMode));
}

class APIForgeApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  const APIForgeApp({super.key, this.initialThemeMode = ThemeMode.system});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppThemeProvider(initialThemeMode)),
        ChangeNotifierProvider(create: (_) => CollectionService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
        ChangeNotifierProvider(create: (_) => ProxyService()),
        ChangeNotifierProvider(create: (_) => RequestService()),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'APIForge',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeProvider.themeMode,
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}

/// Root widget that decides whether to show auth or the main app.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    // Restore token on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAuthenticated) {
          return const HomeScreen();
        }
        return const AuthScreen();
      },
    );
  }
}
