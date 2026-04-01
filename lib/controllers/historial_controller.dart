import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/local_cache_service.dart'; // Tu archivero

class HistorialController extends ChangeNotifier {
  final Map<String, dynamic> userData;
  final LocalCacheService _cacheService = LocalCacheService();

  // Estados de carga
  bool _isLoading = true;
  bool _isLoadingMore = false; // Nuevo: Para el loader del fondo (Lazy Loading)
  bool _hasMore = true; // Nuevo: Para saber si la DB ya no tiene más datos
  int _limiteActual = 20; // Nuevo: Empezamos pidiendo 20 elementos

  String _error = '';
  List<dynamic> _historialCompleto = [];
  List<dynamic> _historialFiltrado = [];
  String _filtroActual = 'todos';
  DateTime _ultimaSincronizacion = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isFetching = false;

  // Exponemos las variables para la UI
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get error => _error;
  List<dynamic> get historialFiltrado => _historialFiltrado;
  String get filtroActual => _filtroActual;

  late io.Socket socket;

  HistorialController(this.userData) {
    _inicializarDatos();
    _conectarSocket();
  }

  // Inicialización de los datos
  Future<void> _inicializarDatos() async {
    // Dibujar lo que hay en cache mientras traemos datos del servidor
    final datosCacheados = await _cacheService.obtenerHistorial();
    if (datosCacheados != null && datosCacheados.isNotEmpty) {
      _historialCompleto = datosCacheados;
      _aplicarFiltroInterno(_filtroActual);
      _isLoading = false;
      notifyListeners();
    }
    // Pedir datos al servidor (si no hay cache o para actualizar)
    await cargarHistorialPublico(reiniciar: true);
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
      // Si nos cobran, reiniciamos la lista para ver el nuevo cobro arriba
      cargarHistorialPublico(reiniciar: true);
    });
  }

  // carga desde el servidor, con opción de reiniciar (para pull-to-refresh) o cargar más (para lazy loading)
  Future<void> cargarHistorialPublico({bool reiniciar = false}) async {
    if (reiniciar) {
      _limiteActual = 20;
      _hasMore = true;
      if (_historialCompleto.isEmpty) {
        _isLoading = true;
        notifyListeners();
      }
    }

    final idUsuario = userData['id'] ?? userData['_id'];

    final result = await ApiService.obtenerHistorial(
      idUsuario,
      limite: _limiteActual,
    );

    if (result.containsKey('error')) {
      _error = result['error'];
      _isLoading = false;
      notifyListeners();
    } else {
      final nuevosDatos = result['historial'] ?? [];

      _historialCompleto = nuevosDatos;

      // Si el servidor nos devolvió menos de lo que pedimos,
      // significa que ya topamos con el final de la base de datos
      if (nuevosDatos.length < _limiteActual) {
        _hasMore = false;
      }

      _aplicarFiltroInterno(_filtroActual);
      _isLoading = false;

      // Actualizamos la bóveda con los datos frescos
      await _cacheService.guardarHistorial(
        _historialCompleto.take(20).toList(),
      );
      notifyListeners();
    }
  }

  // Lazy Loading: Cargar más datos cuando el usuario llegue al final de la lista
  Future<void> cargarMasDatos() async {
    // Si ya estamos cargando o ya no hay más, no hacemos nada
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    // Pedimos 20 registros adicionales
    _limiteActual += 20;
    await cargarHistorialPublico(reiniciar: false);

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<String?> recargaSilenciosa() async {
    if (_isFetching) return null;
    if (DateTime.now().difference(_ultimaSincronizacion).inSeconds < 3) {
      return null;
    }

    _isFetching = true;
    final idUsuario = userData['id'] ?? userData['_id'];

    // El pull-to-refresh siempre resetea a 20 elementos
    final result = await ApiService.obtenerHistorial(idUsuario, limite: 20);
    _isFetching = false;

    if (result.containsKey('error')) {
      return "Sin conexión. Mostrando datos guardados.";
    }

    _historialCompleto = result['historial'] ?? [];
    _limiteActual = 20;
    _hasMore = _historialCompleto.length == 20;

    _aplicarFiltroInterno(_filtroActual);
    await _cacheService.guardarHistorial(_historialCompleto);

    _ultimaSincronizacion = DateTime.now();
    notifyListeners();
    return null;
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
