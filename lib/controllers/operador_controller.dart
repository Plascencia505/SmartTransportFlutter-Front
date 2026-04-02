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
      // 1. Decodificamos el NUEVO formato de QR (HMAC)
      final Map<String, dynamic> dataQR = jsonDecode(qrString);

      // Si el QR no tiene nuestra estructura, lo botamos
      if (!dataQR.containsKey('idBoleto') || !dataQR.containsKey('firma')) {
        throw const FormatException("Estructura de QR incorrecta");
      }

      final String idPasajero = dataQR['idPasajero'];
      final String idBoleto = dataQR['idBoleto'];
      final String firma = dataQR['firma'];

      // 2. Intentamos validar el boleto en línea con el backend
      final result =
          await ApiService.utilizarBoleto(
            idPasajero,
            userData['id'],
            idBoleto, // Pasamos el nuevo UUID
            firma, // Pasamos la nueva firma
          ).timeout(
            const Duration(seconds: 4), // Timeout rápido para no trabar la fila
            onTimeout: () => {'error': 'offline'},
          );

      if (result.containsKey('error')) {
        final errorMsg = result['error'].toString().toLowerCase();

        // 3. LA MAGIA OFFLINE: Si falla la red, guardamos en la mochila local
        if (errorMsg.contains('conexión') ||
            errorMsg.contains('offline') ||
            errorMsg.contains('espera') ||
            errorMsg.contains('red') ||
            errorMsg.contains('timeout')) {
          await _dbOffline.guardarViajePendiente(idPasajero, idBoleto, firma);
          await cargarPendientes(); // Actualizamos el numerito visual

          _isProcessing = false;
          notifyListeners();
          return {
            'status': 'offline_success',
            'message': '¡Validado! (Modo Offline)',
          };
        }
        // 4. FRAUDE O FALLO GLOBAL (Respuesta negativa del servidor)
        else {
          _isProcessing = false;
          notifyListeners();
          return {'status': 'error', 'message': result['error']};
        }
      }

      // 5. ÉXITO ONLINE NORMAL
      _isProcessing = false;
      notifyListeners();

      // Efecto remolque: Como sí hay red, despertamos al mensajero por si hay rezagados
      SyncWorkerService().sincronizarPendientes();

      return {
        'status': 'online_success',
        'message': '¡Pasaje Validado en Nube!',
      };
    } catch (e) {
      // Si escanean una botella de refresco, un QR viejo (TOTP) o basura
      _isProcessing = false;
      notifyListeners();
      return {
        'status': 'invalid_qr',
        'message': 'QR Inválido o de otro sistema',
      };
    }
  }
}
