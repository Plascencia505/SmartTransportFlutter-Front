import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/screens/chofer_screen.dart';
import 'package:transporte_app/screens/registro_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/screens/main_wrapper_screen.dart'; // <--- El envoltorio padre
// Quitamos la importación directa del dashboard_screen porque el wrapper se encarga de eso

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identificadorCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _ocultarPassword = true;

  void _iniciarSesion() async {
    setState(() => _isLoading = true);

    final result = await ApiService.login(
      _identificadorCtrl.text.trim(),
      _passwordCtrl.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      // -Guardamos la sesión y el token en la bóveda segura para mantener al usuario logueado-
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'userData',
        value: jsonEncode(result['dashboard']),
      );
      if (result.containsKey('token')) {
        await storage.write(key: 'jwt_token', value: result['token']);
      }

      if (!mounted) {
        return;
      }

      // --- ENRUTAMIENTO CORREGIDO ---
      if (result['dashboard']['rol'] == 'operador') {
        // Si es chofer, va a su pantalla normal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChoferScreen(userData: result['dashboard']),
          ),
        );
      } else {
        // Si es pasajero, ¡lo mandamos al Wrapper para que tenga la barra inferior!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MainWrapperScreen(userData: result['dashboard']),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bus, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Transporte Inteligente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _identificadorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo o Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _ocultarPassword = !_ocultarPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _iniciarSesion,
                      child: const Text(
                        'Iniciar Sesión',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistroScreen(),
                    ),
                  );
                },
                child: const Text('¿No tienes cuenta? Regístrate aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
