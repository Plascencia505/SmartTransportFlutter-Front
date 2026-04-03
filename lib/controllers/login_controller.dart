import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginController extends ChangeNotifier {
  final TextEditingController identificadorCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _ocultarPassword = true;

  bool get isLoading => _isLoading;
  bool get ocultarPassword => _ocultarPassword;

  void togglePasswordVisibility() {
    _ocultarPassword = !_ocultarPassword;
    notifyListeners();
  }

  // Retorna un Map con el resultado para que la vista decida a dónde navegar o qué error mostrar
  Future<Map<String, dynamic>> iniciarSesion() async {
    final identificador = identificadorCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (identificador.isEmpty || password.isEmpty) {
      return {'error': 'Por favor, ingresa tus credenciales.'};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.login(identificador, password);

      if (result.containsKey('error')) {
        _isLoading = false;
        notifyListeners();
        return {'error': result['error']};
      }

      // Guardamos la sesión y el token en la bóveda segura
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'userData',
        value: jsonEncode(result['dashboard']),
      );
      if (result.containsKey('token')) {
        await storage.write(key: 'jwt_token', value: result['token']);
      }

      _isLoading = false;
      notifyListeners();

      // Devolvemos éxito y los datos necesarios para la navegación
      return {
        'exito': true,
        'rol': result['dashboard']['rol'],
        'dashboard': result['dashboard'],
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'error': 'Error de conexión al servidor.'};
    }
  }

  @override
  void dispose() {
    identificadorCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }
}
