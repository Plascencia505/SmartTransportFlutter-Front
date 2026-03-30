import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:transporte_app/services/api_service.dart';

class PerfilController extends ChangeNotifier {
  // Quitamos el 'final' para poder actualizar los datos
  Map<String, dynamic> userData;
  bool isLoading = true;

  PerfilController(this.userData) {
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    final idUsuario = userData['id'] ?? userData['_id'];

    final result = await ApiService.obtenerPerfil(idUsuario);

    if (!result.containsKey('error')) {
      userData = {...userData, ...result};
    }

    isLoading = false;
    notifyListeners(); // Avisamos a la UI que ya llegaron los datos
  }

  Future<void> cerrarSesion(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
