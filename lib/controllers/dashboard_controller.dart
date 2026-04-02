import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/local_cache_service.dart';

class DashboardController extends ChangeNotifier {
  final Map<String, dynamic> userData;
  final LocalCacheService _cacheService = LocalCacheService();

  double _saldoActual = 0.0;
  int _boletosActuales = 0;
  bool _isLoading = false;
  bool _isSyncing = true;
  bool _isFetching = false;
  DateTime _ultimaSincronizacion = DateTime.fromMillisecondsSinceEpoch(0);

  // Aquí guardaremos el JSON final del QR ya empaquetado
  String _codigoQRActual = '';
  Map<String, dynamic>? _ultimoViaje;

  // Getters
  double get saldoActual => _saldoActual;
  int get boletosActuales => _boletosActuales;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get codigoQRActual => _codigoQRActual;
  Map<String, dynamic>? get ultimoViaje => _ultimoViaje;

  final double limiteMaxRecarga = 1000.0;
  final int limiteMaxBoletos = 50;

  late io.Socket socket;

  // Callback actualizado para recibir el mensaje
  Function(int boletosRestantes, String mensaje)? onBoletoCobradoCallback;

  DashboardController(this.userData) {
    _inicializarDatos();
    _conectarSocket();
    generarBoletoSeguro();
  }

  // Inicio y lectura de datos en cahe local para mostrar algo al instante
  Future<void> _inicializarDatos() async {
    final cacheDash = await _cacheService.obtenerDashboard();
    _saldoActual = (cacheDash?['saldo'] ?? userData['saldo'] ?? 0).toDouble();
    _boletosActuales =
        cacheDash?['boletosDisponibles'] ?? userData['boletosDisponibles'] ?? 0;

    _ultimoViaje = await _cacheService.obtenerUltimoViaje();
    notifyListeners();

    if (_ultimoViaje == null) {
      _buscarUltimoViajeEnServidor();
    }

    await _sincronizarConServidor();
  }

  Future<void> _buscarUltimoViajeEnServidor() async {
    final result = await ApiService.obtenerHistorial(
      userData['id'],
      limite: 20,
    );
    if (!result.containsKey('error')) {
      final lista = result['historial'] as List<dynamic>? ?? [];
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

  Future<void> _actualizarBovedasLocales() async {
    await _cacheService.guardarDashboard({
      'saldo': _saldoActual,
      'boletosDisponibles': _boletosActuales,
    });

    Map<String, dynamic> usuarioActualizado = Map<String, dynamic>.from(
      userData,
    );
    usuarioActualizado['saldo'] = _saldoActual;
    usuarioActualizado['boletosDisponibles'] = _boletosActuales;
    const storage = FlutterSecureStorage();
    await storage.write(key: 'userData', value: jsonEncode(usuarioActualizado));
  }

  void generarBoletoSeguro() {
    final String semilla = userData['totpSecret']?.toString().trim() ?? '';
    if (semilla.isEmpty) return;

    //"Folio"
    final String idBoleto = const Uuid().v4();
    //Firma
    final List<int> bytesSecreto = utf8.encode(semilla);
    final List<int> bytesBoleto = utf8.encode(idBoleto);
    final Hmac hmacSha256 = Hmac(sha256, bytesSecreto);
    final String firma = hmacSha256.convert(bytesBoleto).toString();

    // Empaquetar el QR
    final Map<String, dynamic> payload = {
      'idPasajero': userData['id'],
      'idBoleto': idBoleto,
      'firma': firma,
    };

    _codigoQRActual = jsonEncode(payload);
    notifyListeners();
  }

  // --- WEB SOCKETS ---
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

    socket.on('boleto_cobrado', (data) async {
      if (data['idPasajero'] == userData['id']) {
        _boletosActuales = data['boletosRestantes'];

        _ultimoViaje = {
          'tipo': 'viaje',
          'titulo': 'Abordaje en transporte',
          'fecha': DateTime.now().toUtc().toIso8601String(),
        };

        generarBoletoSeguro();

        _actualizarBovedasLocales();
        _cacheService.guardarUltimoViaje(_ultimoViaje!);

        notifyListeners();
        onBoletoCobradoCallback?.call(
          data['boletosRestantes'],
          data['mensaje'] ?? '¡Pasaje pagado con éxito!',
        );
      }
    });
  }

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
    super.dispose();
  }
}
