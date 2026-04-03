import 'package:flutter/material.dart';
import 'package:transporte_app/services/api_service.dart';

class RegistroController extends ChangeNotifier {
  // Llaves de los formularios
  final List<GlobalKey<FormState>> formKeys = [
    GlobalKey<FormState>(), // Paso 1: Identidad
    GlobalKey<FormState>(), // Paso 2: Contacto
    GlobalKey<FormState>(), // Paso 3: Seguridad
  ];

  // Controladores de texto
  final nombresCtrl = TextEditingController();
  final apellidosCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmarPasswordCtrl = TextEditingController();
  final fechaNacimientoCtrl = TextEditingController();
  final curpCtrl = TextEditingController();
  final cuentaCtrl = TextEditingController();

  // Estados
  bool _isLoading = false;
  int _currentStep = 0;
  bool _ocultarPassword = true;
  bool _ocultarConfirmarPassword = true;
  String _ocupacionSeleccionada = 'general';
  DateTime? _fechaSeleccionada;

  // Lista para saber si un paso tiene errores
  final List<bool> _pasosConError = [false, false, false];

  // Getters
  bool get isLoading => _isLoading;
  int get currentStep => _currentStep;
  bool get ocultarPassword => _ocultarPassword;
  bool get ocultarConfirmarPassword => _ocultarConfirmarPassword;
  String get ocupacionSeleccionada => _ocupacionSeleccionada;
  DateTime? get fechaSeleccionada => _fechaSeleccionada;
  List<bool> get pasosConError => _pasosConError;

  // Setters y Toggles
  void togglePassword() {
    _ocultarPassword = !_ocultarPassword;
    notifyListeners();
  }

  void toggleConfirmarPassword() {
    _ocultarConfirmarPassword = !_ocultarConfirmarPassword;
    notifyListeners();
  }

  void setOcupacion(String valor) {
    _ocupacionSeleccionada = valor;
    notifyListeners();
  }

  void setFechaSeleccionada(DateTime fecha) {
    _fechaSeleccionada = fecha;
    fechaNacimientoCtrl.text =
        "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

    // Si había error en el paso de contacto, revalidar al cambiar fecha
    if (_pasosConError[1]) {
      formKeys[1].currentState?.validate();
    }
    notifyListeners();
  }

  void irAPaso(int paso) {
    if (paso == _currentStep) return;

    if (formKeys[_currentStep].currentState!.validate()) {
      _currentStep = paso;
    } else {
      _pasosConError[_currentStep] = true;
    }
    notifyListeners();
  }

  void retrocederPaso() {
    if (_currentStep > 0) {
      _currentStep -= 1;
      notifyListeners();
    }
  }

  // Retorna true si avanzó, false si hay error de validación, y null si terminó el registro
  Future<Map<String, dynamic>?> avanzarPaso() async {
    bool pasoValido = formKeys[_currentStep].currentState!.validate();

    if (pasoValido) {
      _pasosConError[_currentStep] = false;
      if (_currentStep < 2) {
        _currentStep += 1;
        notifyListeners();
        return {'estado': 'avanzo'};
      } else {
        return await _registrar();
      }
    } else {
      _pasosConError[_currentStep] = true;
      notifyListeners();
      return {'estado': 'error_validacion'};
    }
  }

  Future<Map<String, dynamic>> _registrar() async {
    _isLoading = true;
    notifyListeners();

    final datos = {
      "nombres": nombresCtrl.text.trim(),
      "apellidos": apellidosCtrl.text.trim(),
      "telefono": telefonoCtrl.text.trim(),
      "correo": correoCtrl.text.trim(),
      "password": passwordCtrl.text.trim(),
      "ocupacion": _ocupacionSeleccionada,
      "numeroCuenta": _ocupacionSeleccionada == 'estudiante'
          ? cuentaCtrl.text.trim()
          : "",
      "fechaNacimiento": fechaNacimientoCtrl.text.trim(),
      "curp": curpCtrl.text.trim().toUpperCase(),
    };

    try {
      final result = await ApiService.registro(datos);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'error': 'Error de conexión con el servidor.'};
    }
  }

  @override
  void dispose() {
    nombresCtrl.dispose();
    apellidosCtrl.dispose();
    telefonoCtrl.dispose();
    correoCtrl.dispose();
    passwordCtrl.dispose();
    confirmarPasswordCtrl.dispose();
    fechaNacimientoCtrl.dispose();
    curpCtrl.dispose();
    cuentaCtrl.dispose();
    super.dispose();
  }
}
