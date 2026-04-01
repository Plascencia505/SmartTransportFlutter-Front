import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://unangry-ethyl-uncriticizingly.ngrok-free.dev/api';

  //- Función para obtener las cabeceras con el token incluido
  static Future<Map<String, String>> _getHeaders() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  //-INICIO DE SESIÓN (No necesita token)
  static Future<Map<String, dynamic>> login(
    String identificador,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identificador': identificador,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'error': errorBody['error'] ?? 'Error desconocido al iniciar sesión',
        };
      }
    } catch (e) {
      return {'error': 'Error de conexión con el servidor. Revisa tu red.'};
    }
  }

  //-REGISTRO (No necesita token)
  static Future<Map<String, dynamic>> registro(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return {'exito': true};
      } else {
        final errorBody = jsonDecode(response.body);
        return {'error': errorBody['error'] ?? 'Error al registrar'};
      }
    } catch (e) {
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  //-RECARGAR SALDO (SÍ necesita token)
  static Future<Map<String, dynamic>> recargarSaldo(
    String idUsuario,
    double monto,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/transacciones/recargar'),
        headers: headers,
        body: jsonEncode({'idUsuario': idUsuario, 'monto': monto}),
      );

      // Si el token expiró o es inválido, el backend manda error
      if (response.statusCode == 401 || response.statusCode == 400) {
        final errorBody = jsonDecode(response.body);
        return {
          'error':
              errorBody['error'] ??
              'Sesión expirada. Por favor vuelve a iniciar sesión.',
        };
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  //-COMPRAR BOLETOS (SÍ necesita token)
  static Future<Map<String, dynamic>> comprarBoletos(
    String idUsuario,
    int cantidad,
    double costoTotal,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/transacciones/comprar'),
        headers: headers,
        body: jsonEncode({
          'idUsuario': idUsuario,
          'cantidadBoletos': cantidad, // Corregido: antes era solo 'cantidad'
          'costoTotal':
              costoTotal, // Corregido: Agregado para que pase la validación del backend
        }),
      );

      if (response.statusCode == 401 || response.statusCode == 400) {
        final errorBody = jsonDecode(response.body);
        return {'error': errorBody['error'] ?? 'Sesión expirada.'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  //-UTILIZAR BOLETO (SÍ necesita token)
  static Future<Map<String, dynamic>> utilizarBoleto(
    String idPasajero,
    String idOperador,
    String totp,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/transacciones/utilizar'),
        headers: headers,
        body: jsonEncode({
          'idPasajero': idPasajero,
          'idOperador': idOperador,
          'totp': totp,
        }),
      );

      if (response.statusCode == 401 || response.statusCode == 400) {
        final errorBody = jsonDecode(response.body);
        return {'error': errorBody['error'] ?? 'Sesión del operador inválida.'};
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  //-OBTENER HISTORIAL (SÍ necesita token)
  static Future<Map<String, dynamic>> obtenerHistorial(
    String idUsuario, {
    int limite = 20,
  }) async {
    try {
      final headers = await _getHeaders();

      // Inyectamos la variable límite en la URL como Query Parameter
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/$idUsuario/historial?limite=$limite'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Error al cargar el historial.'};
      }
    } catch (e) {
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  // -OBTENER PERFIL (SÍ necesita token)
  static Future<Map<String, dynamic>> obtenerPerfil(String idUsuario) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/$idUsuario/perfil'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Error al sincronizar perfil.'};
      }
    } catch (e) {
      return {'error': 'Error de conexión.'};
    }
  }
}
