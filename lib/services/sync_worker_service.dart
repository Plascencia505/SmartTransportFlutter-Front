import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/db_offline_service.dart';

class SyncWorkerService {
  // Singleton
  static final SyncWorkerService _instancia = SyncWorkerService._interno();
  factory SyncWorkerService() => _instancia;
  SyncWorkerService._interno();

  final DbOfflineService _db = DbOfflineService();
  bool _isSyncing = false;
  StreamSubscription? _subscription;
  String? _idOperador;

  /// Inicia el escucha de red. Se debe llamar una sola vez al iniciar la app del chofer.
  void iniciarVigilante(String idOperador) {
    _idOperador = idOperador;
    debugPrint(
      'SyncWorker: Vigilante de red activado para Operador $_idOperador.',
    );

    // Escuchamos los cambios en la conectividad
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      // Si hay internet
      if (results.any((result) => result != ConnectivityResult.none)) {
        debugPrint(
          'SyncWorker: ¡Internet recuperado! Iniciando sincronización...',
        );
        sincronizarPendientes();
      }
    });
  }

  /// Proceso de vaciado de la bóveda SQLite
  Future<void> sincronizarPendientes() async {
    // Si ya está sincronizando o no sabemos quién es el chofer, abortamos
    if (_isSyncing || _idOperador == null) return;
    _isSyncing = true;

    try {
      // Obtener el lote desde la base de datos local
      final pendientes = await _db.obtenerViajesPendientes();

      if (pendientes.isEmpty) {
        debugPrint('SyncWorker: Nada que sincronizar.');
        _isSyncing = false;
        return;
      }

      debugPrint(
        'SyncWorker: Enviando ${pendientes.length} viajes al servidor...',
      );

      // Mandar lote al backend CON el ID del operador
      final result = await ApiService.sincronizarLoteViajes(
        _idOperador!,
        pendientes,
      );

      if (!result.containsKey('error')) {
        // Limpieza inteligente basada en la respuesta del Node.js
        final List<dynamic> resultadosNode = result['resultados'] ?? [];
        List<int> idsABorrar = [];

        for (var item in resultadosNode) {
          // Borramos de SQLite si el servidor lo cobró ('exito') o si detectó fraude ('rechazado')
          if (item['status'] == 'exito' || item['status'] == 'rechazado') {
            idsABorrar.add(item['idSQLite']);
          }
        }

        if (idsABorrar.isNotEmpty) {
          await _db.borrarViajesSincronizados(idsABorrar);
          debugPrint(
            'SyncWorker: Sincronización exitosa. ${idsABorrar.length} registros borrados.',
          );
        } else {
          debugPrint(
            'SyncWorker: El servidor procesó el lote pero no indicó registros para borrar.',
          );
        }
      } else {
        debugPrint(
          'SyncWorker: El servidor rechazó el lote o falló la conexión. Reintentando después.',
        );
      }
    } catch (e) {
      debugPrint('SyncWorker: Error crítico en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void detenerVigilante() {
    _subscription?.cancel();
    _idOperador = null;
  }
}
