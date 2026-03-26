import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:transporte_app/screens/main_wrapper_screen.dart';
import 'package:transporte_app/screens/chofer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instanciamos la bóveda
  const storage = FlutterSecureStorage();

  // Leemos los datos encriptados
  final String? userDataString = await storage.read(key: 'userData');

  Widget pantallaInicial = const LoginScreen();

  if (userDataString != null) {
    // Si hay datos, los decodificamos y vemos a dónde mandarlo
    final Map<String, dynamic> userData = jsonDecode(userDataString);
    if (userData['rol'] == 'operador') {
      pantallaInicial = ChoferScreen(userData: userData);
    } else {
      pantallaInicial = MainWrapperScreen(userData: userData);
    }
  }

  runApp(TransporteApp(pantallaInicial: pantallaInicial));
}

class TransporteApp extends StatelessWidget {
  final Widget pantallaInicial;

  const TransporteApp({super.key, required this.pantallaInicial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pago electrónico de transporte público',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: pantallaInicial,
    );
  }
}
