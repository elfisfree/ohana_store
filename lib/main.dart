// lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohana_store/core/app_router.dart';
import 'package:ohana_store/core/constants.dart';
import 'package:ohana_store/features/auth/auth_notifier.dart';
import 'package:ohana_store/features/cart/cart_provider.dart';
import 'package:ohana_store/features/catalog/catalog_provider.dart';
import 'package:ohana_store/features/favorites/favorites_provider.dart';
import 'package:ohana_store/features/profile/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
      ],
      child: const OhanaStoreApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class OhanaStoreApp extends StatefulWidget {
  const OhanaStoreApp({super.key});

  @override
  State<OhanaStoreApp> createState() => _OhanaStoreAppState();
}

class _OhanaStoreAppState extends State<OhanaStoreApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authNotifier = context.read<AuthNotifier>();
    _router = createRouter(authNotifier);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Ohana Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      locale: const Locale('ru', 'RU'),
      routerConfig: _router,
    );
  }
}
