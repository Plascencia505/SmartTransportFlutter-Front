import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/services/api_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(), // Paso 1: Identidad
    GlobalKey<FormState>(), // Paso 2: Contacto
    GlobalKey<FormState>(), // Paso 3: Seguridad
  ];

  // Controladores
  final _nombresCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarPasswordCtrl = TextEditingController();
  final _fechaNacimientoCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _cuentaCtrl = TextEditingController();

  // Estado
  bool _ocultarPassword = true;
  bool _ocultarConfirmarPassword = true;
  String _ocupacionSeleccionada = 'general';
  bool _isLoading = false;
  int _currentStep = 0;
  DateTime? _fechaSeleccionada;

  // Lista para saber si un paso tiene errores y activar la validación reactiva
  final List<bool> _pasosConError = [false, false, false];

  // Función para mostrar el selector de fecha
  Future<void> _seleccionarFecha(BuildContext context) async {
    // Cerramos el teclado si está abierto por UX
    FocusScope.of(context).unfocus();

    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null && seleccion != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = seleccion;
        _fechaNacimientoCtrl.text =
            "${seleccion.year}-${seleccion.month.toString().padLeft(2, '0')}-${seleccion.day.toString().padLeft(2, '0')}";
      });
      if (_pasosConError[1]) {
        _formKeys[1].currentState?.validate();
      }
    }
  }

  //Función para avanzar al siguiente paso o registrar si es el último
  void _avanzarPaso() {
    bool pasoValido = _formKeys[_currentStep].currentState!.validate();

    setState(() {
      if (pasoValido) {
        _pasosConError[_currentStep] = false;
        if (_currentStep < 2) {
          _currentStep += 1;
        } else {
          _registrar();
        }
      } else {
        _pasosConError[_currentStep] = true;
      }
    });
  }

  void _registrar() async {
    setState(() => _isLoading = true);

    final datos = {
      "nombres": _nombresCtrl.text.trim(),
      "apellidos": _apellidosCtrl.text.trim(),
      "telefono": _telefonoCtrl.text.trim(),
      "correo": _correoCtrl.text.trim(),
      "password": _passwordCtrl.text.trim(),
      "ocupacion": _ocupacionSeleccionada,
      "numeroCuenta": _ocupacionSeleccionada == 'estudiante'
          ? _cuentaCtrl.text.trim()
          : "",
      "fechaNacimiento": _fechaNacimientoCtrl.text.trim(),
      "curp": _curpCtrl.text.trim().toUpperCase(),
    };

    final result = await ApiService.registro(datos);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Inicia sesión.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(title: const Text('Crear Cuenta'), elevation: 0),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                physics: const ClampingScrollPhysics(),
                onStepTapped: (step) {
                  if (step == _currentStep) return;

                  if (_formKeys[_currentStep].currentState!.validate()) {
                    setState(() => _currentStep = step);
                  } else {
                    setState(() => _pasosConError[_currentStep] = true);
                  }
                },
                onStepContinue: _avanzarPaso,
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _currentStep == 2
                                  ? 'Finalizar Registro'
                                  : 'Continuar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_currentStep > 0)
                          Expanded(
                            child: TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text(
                                'Atrás',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                steps: [
                  // Primer paso: Identidad
                  Step(
                    state: _pasosConError[0]
                        ? StepState.error
                        : (_currentStep > 0
                              ? StepState.complete
                              : StepState.indexed),
                    isActive: _currentStep >= 0,
                    title: const Text(
                      'Identidad',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    content: Form(
                      key: _formKeys[0],
                      autovalidateMode: _pasosConError[0]
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nombresCtrl,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombres',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Ingresa tus nombres' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _apellidosCtrl,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Ingresa tus apellidos' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _curpCtrl,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 18,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'CURP',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v!.length != 18
                                ? 'La CURP debe tener exactamente 18 caracteres'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Segundo paso: contacto
                  Step(
                    state: _pasosConError[1]
                        ? StepState.error
                        : (_currentStep > 1
                              ? StepState.complete
                              : StepState.indexed),
                    isActive: _currentStep >= 1,
                    title: const Text(
                      'Contacto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    content: Form(
                      key: _formKeys[1],
                      autovalidateMode: _pasosConError[1]
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _telefonoCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (v) => v!.length != 10
                                ? 'Debe tener 10 dígitos'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _correoCtrl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (v) {
                              if (v!.isEmpty) return 'Ingresa tu correo';
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(v)) {
                                return 'Ingresa un correo válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _fechaNacimientoCtrl,
                            readOnly: true,
                            onTap: () => _seleccionarFecha(context),
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Nacimiento',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                            validator: (v) {
                              if (v!.isEmpty) {
                                return 'Selecciona tu fecha de nacimiento';
                              }
                              String curp = _curpCtrl.text.trim().toUpperCase();
                              if (curp.length >= 10 &&
                                  _fechaSeleccionada != null) {
                                String year = _fechaSeleccionada!.year
                                    .toString()
                                    .substring(2, 4);
                                String month = _fechaSeleccionada!.month
                                    .toString()
                                    .padLeft(2, '0');
                                String day = _fechaSeleccionada!.day
                                    .toString()
                                    .padLeft(2, '0');
                                String fechaEsperada = "$year$month$day";
                                String fechaEnCurp = curp.substring(4, 10);

                                if (fechaEsperada != fechaEnCurp) {
                                  return 'Los datos de identidad no coinciden. Verifica tu información.';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tercer paso: seguridad
                  Step(
                    state: _pasosConError[2]
                        ? StepState.error
                        : StepState.indexed,
                    isActive: _currentStep >= 2,
                    title: const Text(
                      'Seguridad',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    content: Form(
                      key: _formKeys[2],
                      autovalidateMode: _pasosConError[2]
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _ocupacionSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Ocupación',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'general',
                                child: Text('Público General'),
                              ),
                              DropdownMenuItem(
                                value: 'estudiante',
                                child: Text('Estudiante'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _ocupacionSeleccionada = val!),
                          ),
                          if (_ocupacionSeleccionada == 'estudiante') ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cuentaCtrl,
                              textInputAction: TextInputAction.next,
                              maxLength: 8,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Número de Cuenta',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v!.length != 8
                                  ? 'Debe tener exactamente 8 dígitos'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            textInputAction: TextInputAction.next,
                            obscureText: _ocultarPassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _ocultarPassword = !_ocultarPassword,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v!.length < 8 ? 'Mínimo 8 caracteres' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmarPasswordCtrl,
                            textInputAction: TextInputAction
                                .done, // Último campo, el teclado muestra "Hecho"
                            obscureText: _ocultarConfirmarPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirmar Contraseña',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarConfirmarPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _ocultarConfirmarPassword =
                                      !_ocultarConfirmarPassword,
                                ),
                              ),
                            ),
                            validator: (v) => v != _passwordCtrl.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
