import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/db_offline_service.dart';

class SyncWorkerService extends ChangeNotifier {
  // Singleton
  static final SyncWorkerService _instancia = SyncWorkerService._interno();
  factory SyncWorkerService() => _instancia;
  SyncWorkerService._interno();

  final DbOfflineService _db = DbOfflineService();
  bool _isSyncing = false;

  // Getter para que la UI sepa si estamos sincronizando o no
  bool get isSyncing => _isSyncing;

  StreamSubscription? _subscription;
  Timer? _timer;
  String? _idOperador;

  /// Arranca el reloj SOLO si no estaba ya corriendo
  void despertarReloj() {
    if (_timer != null && _timer!.isActive) return; // Ya está trabajando

    debugPrint('SyncWorker: Despertando el reloj de 30s...');
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      sincronizarPendientes();
    });
  }

  /// Apaga el reloj para ahorrar batería
  void apagarReloj() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      _timer = null;
      debugPrint(
        'SyncWorker: Mochila vacía. Reloj apagado para ahorrar batería.',
      );
    }
  }

  /// Inicia el escucha de red. Se debe llamar una sola vez al iniciar la app del chofer.
  void iniciarVigilante(String idOperador) {
    _idOperador = idOperador;
    debugPrint(
      'SyncWorker: Vigilante de red activado para Operador $_idOperador.',
    );

    // Revisar si hay viajes de la sesión anterior
    _db.obtenerViajesPendientes().then((pendientes) {
      if (pendientes.isNotEmpty) {
        debugPrint('SyncWorker: Se encontraron viajes de la sesión anterior.');
        despertarReloj();
      }
    });

    // Escuchar eventos de conexión
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        debugPrint(
          'SyncWorker: ¡Cambio de red detectado! Iniciando sincronización...',
        );
        sincronizarPendientes();
      }
    });

    // Intentar sincronizar al iniciar por si ya hay conexión, así no esperamos al cambio de red
    Connectivity().checkConnectivity().then((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        debugPrint(
          'SyncWorker: Conexión detectada al inicio. Sincronizando...',
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
    notifyListeners();

    try {
      // Obtener el lote desde la base de datos local
      final pendientes = await _db.obtenerViajesPendientes();

      if (pendientes.isEmpty) {
        apagarReloj();
        _isSyncing = false;
        notifyListeners();
        return;
      }

      debugPrint(
        'SyncWorker: Enviando ${pendientes.length} viajes al servidor...',
      );

      final result = await ApiService.sincronizarLoteViajes(
        _idOperador!,
        pendientes,
      );

      if (!result.containsKey('error')) {
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
        // Si se rechaza el lote no lo borramos para reintentar después
        debugPrint(
          'SyncWorker: El servidor rechazó el lote o falló la conexión. Reintentando después.',
        );
      }
    } catch (e) {
      debugPrint('SyncWorker: Error crítico en sincronización: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void detenerVigilante() {
    _subscription?.cancel();
    apagarReloj();
    _idOperador = null;
  }
}
