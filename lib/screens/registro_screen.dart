import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/registro_controller.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  late RegistroController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RegistroController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    FocusScope.of(context).unfocus();

    final DateTime? seleccion = await showDatePicker(
      context: context,
      // 1. MEMORIA: Si ya hay fecha seleccionada, inicia ahí; si no, en 2005.
      initialDate: _controller.fechaSeleccionada ?? DateTime(2005),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      // 2. UX: Oculta el icono del lápiz (modo texto) para un look más limpio
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      // 3. UX: Para cumpleaños es mejor elegir el año primero, no el día
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null && seleccion != _controller.fechaSeleccionada) {
      _controller.setFechaSeleccionada(seleccion);
    }
  }

  void _procesarAvance() async {
    FocusScope.of(context).unfocus();

    final resultado = await _controller.avanzarPaso();

    if (!mounted || resultado == null) return;

    if (resultado['estado'] == 'error_validacion') {
      HapticFeedback.heavyImpact(); // Error de formulario
    } else if (resultado['estado'] == 'avanzo') {
      HapticFeedback.lightImpact(); // Cambio de paso suave
    } else {
      // Significa que devolvió la respuesta de la API de registro
      if (resultado.containsKey('error')) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado['error'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Registro exitoso! Ya puedes iniciar sesión.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), // Fondo RUTAPA
        appBar: AppBar(
          title: const Text(
            'Crear Cuenta',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          backgroundColor: const Color(0xFFF5F7FA),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            if (_controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 3,
                ),
              );
            }

            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.blueAccent,
                ),
              ),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _controller.currentStep,
                physics: const BouncingScrollPhysics(),
                onStepTapped: _controller.irAPaso,
                onStepContinue: _procesarAvance,
                onStepCancel: () {
                  HapticFeedback.selectionClick();
                  if (_controller.currentStep > 0) {
                    _controller.retrocederPaso();
                  } else {
                    Navigator.pop(context);
                  }
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _controller.currentStep == 2
                                    ? 'Finalizar Registro'
                                    : 'Continuar',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_controller.currentStep > 0)
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: TextButton(
                                onPressed: details.onStepCancel,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Atrás',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                steps: [
                  _buildPasoIdentidad(),
                  _buildPasoContacto(context),
                  _buildPasoSeguridad(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Pasos individuales del Stepper

  Step _buildPasoIdentidad() {
    return Step(
      state: _controller.pasosConError[0]
          ? StepState.error
          : (_controller.currentStep > 0
                ? StepState.complete
                : StepState.indexed),
      isActive: _controller.currentStep >= 0,
      title: const Text(
        'Identidad',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Form(
        key: _controller.formKeys[0],
        autovalidateMode: _controller.pasosConError[0]
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildTextField(
              controller: _controller.nombresCtrl,
              label: 'Nombres',
              icon: Icons.person_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.isEmpty ? 'Ingresa tus nombres' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.apellidosCtrl,
              label: 'Apellidos',
              icon: Icons.badge_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.isEmpty ? 'Ingresa tus apellidos' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.curpCtrl,
              label: 'CURP',
              icon: Icons.fingerprint_rounded,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              maxLength: 18,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              validator: (v) => v!.length != 18
                  ? 'Debe tener exactamente 18 caracteres'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Step _buildPasoContacto(BuildContext context) {
    return Step(
      state: _controller.pasosConError[1]
          ? StepState.error
          : (_controller.currentStep > 1
                ? StepState.complete
                : StepState.indexed),
      isActive: _controller.currentStep >= 1,
      title: const Text(
        'Contacto',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Form(
        key: _controller.formKeys[1],
        autovalidateMode: _controller.pasosConError[1]
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildTextField(
              controller: _controller.telefonoCtrl,
              label: 'Teléfono',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  v!.length != 10 ? 'Debe tener 10 dígitos' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.correoCtrl,
              label: 'Correo Electrónico',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v!.isEmpty) return 'Ingresa tu correo';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.fechaNacimientoCtrl,
              label: 'Fecha de Nacimiento',
              icon: Icons.calendar_month_rounded,
              readOnly: true,
              onTap: () => _seleccionarFecha(context),
              validator: (v) {
                if (v!.isEmpty) return 'Selecciona tu fecha de nacimiento';
                String curp = _controller.curpCtrl.text.trim().toUpperCase();
                if (curp.length >= 10 &&
                    _controller.fechaSeleccionada != null) {
                  String year = _controller.fechaSeleccionada!.year
                      .toString()
                      .substring(2, 4);
                  String month = _controller.fechaSeleccionada!.month
                      .toString()
                      .padLeft(2, '0');
                  String day = _controller.fechaSeleccionada!.day
                      .toString()
                      .padLeft(2, '0');
                  if ("$year$month$day" != curp.substring(4, 10)) {
                    return 'La fecha no coincide con tu CURP.';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Step _buildPasoSeguridad() {
    return Step(
      state: _controller.pasosConError[2] ? StepState.error : StepState.indexed,
      isActive: _controller.currentStep >= 2,
      title: const Text(
        'Seguridad',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Form(
        key: _controller.formKeys[2],
        autovalidateMode: _controller.pasosConError[2]
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _controller.ocupacionSeleccionada,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade600,
              ),
              decoration: _inputDecoration(
                label: 'Ocupación',
                icon: Icons.work_rounded,
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
              onChanged: (val) => _controller.setOcupacion(val!),
            ),
            if (_controller.ocupacionSeleccionada == 'estudiante') ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _controller.cuentaCtrl,
                label: 'Número de Cuenta',
                icon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    v!.length != 8 ? 'Debe tener exactamente 8 dígitos' : null,
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.passwordCtrl,
              label: 'Contraseña',
              icon: Icons.lock_rounded,
              obscureText: _controller.ocultarPassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                icon: Icon(
                  _controller.ocultarPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: _controller.togglePassword,
              ),
              validator: (v) => v!.length < 8 ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _controller.confirmarPasswordCtrl,
              label: 'Confirmar Contraseña',
              icon: Icons.lock_clock_rounded,
              obscureText: _controller.ocultarConfirmarPassword,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  _controller.ocultarConfirmarPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: _controller.toggleConfirmarPassword,
              ),
              validator: (v) => v != _controller.passwordCtrl.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Funciones complementarias para mantener el código organizado y reutilizable

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      buildCounter: maxLength != null
          ? (context, {required currentLength, required isFocused, maxLength}) {
              if (!isFocused && currentLength == 0) return null;

              final bool completado = currentLength == maxLength;
              return Text(
                '$currentLength de $maxLength',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: completado ? FontWeight.w700 : FontWeight.w600,
                  color: completado
                      ? Colors.green.shade600
                      : Colors.grey.shade500,
                ),
              );
            }
          : null,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
      suffixIcon: suffixIcon,
      // Se elimina el counterText: "" que teníamos antes para permitir que buildCounter haga su trabajo
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}
