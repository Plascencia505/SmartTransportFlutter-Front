import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:otp/otp.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/local_cache_service.dart'; // Tu Archivero

// Manda cambios a la UI para que se redibuje
class DashboardController extends ChangeNotifier {
  final Map<String, dynamic> userData;
  final LocalCacheService _cacheService =
      LocalCacheService(); // Instancia del caché

  double _saldoActual = 0.0;
  int _boletosActuales = 0;
  bool _isLoading = false;
  bool _isSyncing = true;
  String _codigoTotpActual = '';
  DateTime _ultimaSincronizacion = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isFetching = false;

  // Novedad: Variable para el Mini-Historial
  Map<String, dynamic>? _ultimoViaje;

  // Getters
  double get saldoActual => _saldoActual;
  int get boletosActuales => _boletosActuales;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get codigoTotpActual => _codigoTotpActual;
  Map<String, dynamic>? get ultimoViaje => _ultimoViaje;

  final double limiteMaxRecarga = 1000.0;
  final int limiteMaxBoletos = 50;

  late io.Socket socket;
  Timer? _timerSincronizacion;
  Timer? _timerPeriodico;

  // Constructor del controlador
  DashboardController(this.userData) {
    _inicializarDatos();
    _conectarSocket();
    _iniciarMotorTOTP();
  }

  // --- PASO 1: ARRANQUE Y LECTURA DE CACHÉ ---
  Future<void> _inicializarDatos() async {
    // 1. Leer Dashboard de caché (si existe) para un arranque más fluido
    final cacheDash = await _cacheService.obtenerDashboard();
    _saldoActual = (cacheDash?['saldo'] ?? userData['saldo'] ?? 0).toDouble();
    _boletosActuales =
        cacheDash?['boletosDisponibles'] ?? userData['boletosDisponibles'] ?? 0;

    // 2. Leer Mini-Historial del Archivero
    _ultimoViaje = await _cacheService.obtenerUltimoViaje();
    notifyListeners(); // Pintamos la UI de inmediato con lo que haya

    // 3. Si no hay último viaje guardado, lo buscamos sigilosamente en el backend
    if (_ultimoViaje == null) {
      _buscarUltimoViajeEnServidor();
    }

    // 4. Pedimos datos frescos de saldo y boletos
    await _sincronizarConServidor();
  }

  // Busca el último viaje si el usuario limpió caché o instaló la app de nuevo
  Future<void> _buscarUltimoViajeEnServidor() async {
    final result = await ApiService.obtenerHistorial(
      userData['id'],
      limite: 20,
    );
    if (!result.containsKey('error')) {
      final lista = result['historial'] as List<dynamic>? ?? [];
      // Buscamos el primero que sea de tipo 'viaje'
      final viaje = lista.firstWhere(
        (item) => item['tipo'] == 'viaje',
        orElse: () => null,
      );
      if (viaje != null) {
        _ultimoViaje = viaje;
        await _cacheService.guardarUltimoViaje(viaje);
        notifyListeners();
      }
    }
  }

  // Centralizamos la función de guardado para no repetir código
  Future<void> _actualizarBovedasLocales() async {
    // Actualizar Bóveda del Dashboard
    await _cacheService.guardarDashboard({
      'saldo': _saldoActual,
      'boletosDisponibles': _boletosActuales,
    });

    // Actualizar también la sesión nativa de Login para que sobreviva cierres forzados
    Map<String, dynamic> usuarioActualizado = Map<String, dynamic>.from(
      userData,
    );
    usuarioActualizado['saldo'] = _saldoActual;
    usuarioActualizado['boletosDisponibles'] = _boletosActuales;
    const storage = FlutterSecureStorage();
    await storage.write(key: 'userData', value: jsonEncode(usuarioActualizado));
  }

  // Control de TOTP
  void _iniciarMotorTOTP() {
    _generarCodigoTOTP();
    final int ahora = DateTime.now().millisecondsSinceEpoch;
    final int msFaltantes = 30000 - (ahora % 30000);

    _timerSincronizacion = Timer(Duration(milliseconds: msFaltantes), () {
      _generarCodigoTOTP();
      _timerPeriodico = Timer.periodic(const Duration(seconds: 30), (timer) {
        _generarCodigoTOTP();
      });
    });
  }

  void _generarCodigoTOTP() {
    final String semilla = userData['totpSecret']?.toString().trim() ?? '';
    if (semilla.isEmpty) return;

    _codigoTotpActual = OTP.generateTOTPCodeString(
      semilla,
      DateTime.now().millisecondsSinceEpoch,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
    notifyListeners();
  }

  // Sockets, recibe un callback de la UI
  void _conectarSocket() {
    String socketUrl = ApiService.baseUrl.replaceAll('/api', '');

    socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Conectado al servidor de Sockets');
      socket.emit('unirse_canal', userData['id']);
    });

    // Servicio en tiempo real
    socket.on('boleto_cobrado', (data) {
      if (data['idPasajero'] == userData['id']) {
        _boletosActuales = data['boletosRestantes'];

        // Creamos un registro temporal del viaje para actualizar el Mini-Historial al instante
        _ultimoViaje = {
          'tipo': 'viaje',
          'titulo': 'Abordaje en transporte',
          'fecha': DateTime.now().toIso8601String(),
        };

        // Guardamos las nuevas verdades
        _actualizarBovedasLocales();
        _cacheService.guardarUltimoViaje(_ultimoViaje!);

        notifyListeners();
        onBoletoCobradoCallback?.call(data['boletosRestantes']);
      }
    });
  }

  Function(int)? onBoletoCobradoCallback;

  Future<void> _sincronizarConServidor() async {
    final result = await ApiService.obtenerPerfil(userData['id']);

    if (!result.containsKey('error')) {
      _saldoActual = (result['saldo'] ?? _saldoActual).toDouble();
      _boletosActuales = result['boletosDisponibles'] ?? _boletosActuales;
      await _actualizarBovedasLocales();
    }
    _isSyncing = false;
    notifyListeners();
  }

  Future<String?> recargaSilenciosa() async {
    if (_isFetching) return null;
    if (DateTime.now().difference(_ultimaSincronizacion).inSeconds < 3) {
      return null;
    }

    _isFetching = true;
    final result = await ApiService.obtenerPerfil(userData['id']);
    _isFetching = false;

    if (result.containsKey('error')) {
      return "Sin conexión. Mostrando datos guardados.";
    }

    _saldoActual = (result['saldo'] ?? _saldoActual).toDouble();
    _boletosActuales = result['boletosDisponibles'] ?? _boletosActuales;
    _ultimaSincronizacion = DateTime.now();

    await _actualizarBovedasLocales();
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>> ejecutarRecarga(double monto) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.recargarSaldo(userData['id'], monto);

    _isLoading = false;
    if (!result.containsKey('error')) {
      _saldoActual = (result['saldoActual']).toDouble();
      await _actualizarBovedasLocales();
    }
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> ejecutarCompra(
    int cantidad,
    double costoTotal,
  ) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.comprarBoletos(
      userData['id'],
      cantidad,
      costoTotal,
    );

    _isLoading = false;
    if (!result.containsKey('error')) {
      _boletosActuales =
          result['boletosDisponibles'] ?? result['boletosActuales'];
      _saldoActual = (result['saldoRestante']).toDouble();
      await _actualizarBovedasLocales();
    }
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _timerSincronizacion?.cancel();
    _timerPeriodico?.cancel();
    super.dispose();
  }
}
