import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/services/local_cache_service.dart';

class PerfilController extends ChangeNotifier {
  Map<String, dynamic> userData;
  bool isLoading = true;

  // Instanciamos nuestro servicio singleton
  final LocalCacheService _cacheService = LocalCacheService();

  PerfilController(this.userData) {
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    final idUsuario = userData['id'] ?? userData['_id'];

    // Leer primero del caché para mostrar algo rápido mientras obtenemos la info fresca del servidor
    final datosCacheados = await _cacheService.obtenerPerfil();
    if (datosCacheados != null) {
      // Si hay datos guardados, los fusionamos y avisamos a la pantalla.
      // Esto hace que, sin internet, la pantalla se pinte al instante.
      userData = {...userData, ...datosCacheados};
      isLoading = false;
      notifyListeners();
    }

    // Consulta al servidor para obtener la info más fresca y actualizar el caché
    final result = await ApiService.obtenerPerfil(idUsuario);

    // Actualizar y guardar el caché
    if (!result.containsKey('error')) {
      userData = {...userData, ...result}; // Fusionamos la info fresca
      await _cacheService.guardarPerfil(result);
    }

    // Si es la primera carga (no había caché), entonces pintamos la pantalla ahora.
    // Si ya habíamos pintado con datos cacheados, esta actualización será transparente para el
    isLoading = false;
    notifyListeners();
  }

  Future<void> cerrarSesion(BuildContext context) async {
    // 1. Borramos las llaves maestras
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    // 2. Limpiamos la caché local para que no quede ningún dato residual
    await _cacheService.limpiarCache();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
