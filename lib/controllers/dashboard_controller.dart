import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:otp/otp.dart';
import 'package:transporte_app/services/api_service.dart';

// Manda cambios a la UI para que se redibuje
class DashboardController extends ChangeNotifier {
  final Map<String, dynamic> userData;

  double _saldoActual = 0.0;
  int _boletosActuales = 0;
  bool _isLoading = false;
  String _codigoTotpActual = '';

  // Usos de getters para que la UI pueda acceder a los datos sin modificar directamente
  double get saldoActual => _saldoActual;
  int get boletosActuales => _boletosActuales;
  bool get isLoading => _isLoading;
  String get codigoTotpActual => _codigoTotpActual;

  final double limiteMaxRecarga = 1000.0;
  final int limiteMaxBoletos = 50;

  late io.Socket socket;
  Timer? _timerSincronizacion;
  Timer? _timerPeriodico;

  // Constructor del controlador
  DashboardController(this.userData) {
    _saldoActual = (userData['saldo'] ?? 0).toDouble();
    _boletosActuales = userData['boletosDisponibles'] ?? 0;

    _sincronizarConServidor();
    _conectarSocket();
    _iniciarMotorTOTP();
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

  //Sockets, recibe un callback de la UI
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

    socket.on('boleto_cobrado', (data) {
      if (data['idPasajero'] == userData['id']) {
        _boletosActuales = data['boletosRestantes'];
        notifyListeners();
        onBoletoCobradoCallback?.call(data['boletosRestantes']);
      }
    });
  }

  // Función que la UI puede asignar para mostrar el diálogo de boleto cobrado
  Function(int)? onBoletoCobradoCallback;

  // L+ogica para sincronizar y llamado de API
  Future<void> _sincronizarConServidor() async {
    final result = await ApiService.obtenerPerfil(userData['id']);

    if (!result.containsKey('error')) {
      _saldoActual = (result['saldo'] ?? _saldoActual).toDouble();
      _boletosActuales = result['boletosDisponibles'] ?? _boletosActuales;
      notifyListeners();

      Map<String, dynamic> usuarioActualizado = userData;
      usuarioActualizado['saldo'] = _saldoActual;
      usuarioActualizado['boletosDisponibles'] = _boletosActuales;

      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'userData',
        value: jsonEncode(usuarioActualizado),
      );
    }
  }

  Future<Map<String, dynamic>> ejecutarRecarga(double monto) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.recargarSaldo(userData['id'], monto);

    _isLoading = false;
    if (!result.containsKey('error')) {
      _saldoActual = (result['saldoActual']).toDouble();
    }
    notifyListeners();
    return result; // Devolvemos el resultado para que la UI muestre el SnackBar
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
    }
    notifyListeners();
    return result;
  }

  // Limpieza al cerrar
  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _timerSincronizacion?.cancel();
    _timerPeriodico?.cancel();
    super.dispose();
  }
}
