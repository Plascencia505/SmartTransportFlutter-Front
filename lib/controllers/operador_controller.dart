import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/db_offline_service.dart';
import 'package:transporte_app/services/sync_worker_service.dart';

class OperadorController extends ChangeNotifier {
  final Map<String, dynamic> userData;
  final DbOfflineService _dbOffline = DbOfflineService();

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // NUEVO: Llevamos el conteo de cuántos viajes offline tenemos atorados
  int _pendientesCount = 0;
  int get pendientesCount => _pendientesCount;

  OperadorController(this.userData) {
    cargarPendientes(); // Contamos al arrancar
  }

  Future<void> cargarPendientes() async {
    final pendientes = await _dbOffline.obtenerViajesPendientes();
    _pendientesCount = pendientes.length;
    notifyListeners();
  }

  /// Procesa el texto del QR escaneado y decide su destino
  Future<Map<String, dynamic>> procesarBoleto(String qrString) async {
    if (_isProcessing) return {'status': 'ignored'};

    _isProcessing = true;
    notifyListeners();

    try {
      final Map<String, dynamic> dataQR = jsonDecode(qrString);

      // Si el QR no tiene nuestra estructura, lo botamos
      if (!dataQR.containsKey('idBoleto') || !dataQR.containsKey('firma')) {
        throw const FormatException("Estructura de QR incorrecta");
      }

      final String idPasajero = dataQR['idPasajero'];
      final String idBoleto = dataQR['idBoleto'];
      final String firma = dataQR['firma'];

      final bool yaFueEscaneado = await _dbOffline.existeBoleto(idBoleto);
      if (yaFueEscaneado) {
        _isProcessing = false;
        notifyListeners();
        return {
          'status': 'error',
          'message': 'Este boleto ya fue escaneado, genera uno nuevo',
        };
      }

      //  Intentar validar el boleto en línea con el backend
      final result =
          await ApiService.utilizarBoleto(
            idPasajero,
            userData['id'],
            idBoleto,
            firma,
          ).timeout(
            const Duration(seconds: 4),
            onTimeout: () => {'error': 'offline'},
          );

      if (result.containsKey('error')) {
        final errorMsg = result['error'].toString().toLowerCase();

        // Si falla la red, guardamos en la mochila local
        if (errorMsg.contains('conexión') ||
            errorMsg.contains('offline') ||
            errorMsg.contains('espera') ||
            errorMsg.contains('red') ||
            errorMsg.contains('timeout')) {
          await _dbOffline.guardarViajePendiente(idPasajero, idBoleto, firma);
          await cargarPendientes();

          _isProcessing = false;
          notifyListeners();
          return {
            'status': 'offline_success',
            'message': '¡Validado! (Modo Offline)',
          };
        }
        // fraude, sin saldo, QR inválido, o error del backend
        else {
          _isProcessing = false;
          notifyListeners();
          return {'status': 'error', 'message': result['error']};
        }
      }

      _isProcessing = false;
      notifyListeners();

      // Activamos la sincronización inmediata para que el viaje offline se suba lo antes posible
      SyncWorkerService().sincronizarPendientes();

      return {
        'status': 'online_success',
        'message': '¡Pasaje Validado en Nube!',
      };
    } catch (e) {
      // Si el QR no es valido
      _isProcessing = false;
      notifyListeners();
      return {
        'status': 'invalid_qr',
        'message': 'QR Inválido o de otro sistema',
      };
    }
  }
}
