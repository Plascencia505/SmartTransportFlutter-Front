import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:transporte_app/services/api_service.dart';

class HistorialController extends ChangeNotifier {
  final Map<String, dynamic> userData;

  bool _isLoading = true;
  String _error = '';
  List<dynamic> _historialCompleto = [];
  List<dynamic> _historialFiltrado = [];
  String _filtroActual = 'todos';

  // Exponemos las variables para que la UI las lea
  bool get isLoading => _isLoading;
  String get error => _error;
  List<dynamic> get historialFiltrado => _historialFiltrado;
  String get filtroActual => _filtroActual;

  late io.Socket socket;

  HistorialController(this.userData) {
    cargarHistorialPublico();
    _conectarSocket();
  }

  void _conectarSocket() {
    String socketUrl = ApiService.baseUrl.replaceAll('/api', '');

    socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      final idUsuario = userData['id'] ?? userData['_id'];
      socket.emit('unirse_canal', idUsuario);
    });

    socket.on('boleto_cobrado', (data) {
      cargarHistorialPublico();
    });
  }

  Future<void> cargarHistorialPublico() async {
    // Solo mostramos el loader de pantalla completa si no hay datos previos
    if (_historialCompleto.isEmpty) {
      _isLoading = true;
      _error = '';
      notifyListeners();
    }

    final idUsuario = userData['id'] ?? userData['_id'];
    final result = await ApiService.obtenerHistorial(idUsuario);

    if (result.containsKey('error')) {
      _error = result['error'];
      _isLoading = false;
      notifyListeners();
    } else {
      _historialCompleto = result['historial'] ?? [];
      _aplicarFiltroInterno(_filtroActual);
      _isLoading = false;
      notifyListeners();
    }
  }

  void cambiarFiltro(String filtro) {
    _filtroActual = filtro;
    _aplicarFiltroInterno(filtro);
    notifyListeners();
  }

  void _aplicarFiltroInterno(String filtro) {
    if (filtro == 'todos') {
      _historialFiltrado = List.from(_historialCompleto);
    } else {
      _historialFiltrado = _historialCompleto
          .where((item) => item['tipo'] == filtro)
          .toList();
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }
}
