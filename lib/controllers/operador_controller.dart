import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/db_offline_service.dart';

class OperadorController extends ChangeNotifier {
  final Map<String, dynamic> userData;
  final DbOfflineService _dbOffline = DbOfflineService();

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  OperadorController(this.userData);

  /// Procesa el texto del QR escaneado y decide su destino
  Future<Map<String, dynamic>> procesarBoleto(String qrString) async {
    if (_isProcessing) return {'status': 'ignored'};

    _isProcessing = true;
    notifyListeners();

    try {
      // Decodificamos el QR para extraer idPasajero y totp
      final Map<String, dynamic> dataQR = jsonDecode(qrString);
      final String idPasajero = dataQR['idPasajero'];
      final String totp = dataQR['totp'];

      // Intentamos validar el boleto en línea con el backend
      final result =
          await ApiService.utilizarBoleto(
            idPasajero,
            userData['id'],
            totp,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => {'error': 'offline'},
          );

      if (result.containsKey('error')) {
        final errorMsg = result['error'].toString().toLowerCase();

        // Si es un error de conexión, guardamos el viaje en la base de datos local para reintentar después
        if (errorMsg.contains('conexión') ||
            errorMsg.contains('offline') ||
            errorMsg.contains('espera')) {
          await _dbOffline.guardarViajePendiente(idPasajero, totp);

          _isProcessing = false;
          notifyListeners();
          return {
            'status': 'offline_success',
            'message': 'Validado (Modo Offline)',
          };
        }
        // Respuesta negativa del servidor
        else {
          _isProcessing = false;
          notifyListeners();
          return {'status': 'error', 'message': result['error']};
        }
      }

      // 5. Éxito Online Normal
      _isProcessing = false;
      notifyListeners();
      return {
        'status': 'online_success',
        'message': '¡Pasaje Validado en Nube!',
      };
    } catch (e) {
      // Si escanean una botella de refresco o un QR de otra cosa
      _isProcessing = false;
      notifyListeners();
      return {'status': 'invalid_qr', 'message': 'QR no reconocido'};
    }
  }
}
