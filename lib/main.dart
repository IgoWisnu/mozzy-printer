import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/printer_provider.dart';
import 'core/providers/socket_provider.dart';
import 'data/services/storage_service.dart';
import 'data/services/thermal_printer_service.dart';
import 'presentation/screens/home_screen.dart';
import 'core/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  await initializeBackgroundService();

  final thermalPrinterService = ThermalPrinterService();

  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<ThermalPrinterService>.value(value: thermalPrinterService),

        // Providers
        ChangeNotifierProvider(
          create: (_) => PrinterProvider(
            storage: storageService,
            thermalService: thermalPrinterService,
          ),
        ),
        ChangeNotifierProvider(create: (_) => SocketProvider()),
      ],
      child: const MozzyPrintApp(),
    ),
  );
}

class MozzyPrintApp extends StatelessWidget {
  const MozzyPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mozzy Print Service',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const HomeScreen(),
    );
  }
}
