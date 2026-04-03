import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/login_controller.dart';
import 'package:transporte_app/screens/chofer_screen.dart';
import 'package:transporte_app/screens/registro_screen.dart';
import 'package:transporte_app/screens/main_wrapper_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _procesarLogin() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus(); // Oculta el teclado al presionar el botón

    final resultado = await _controller.iniciarSesion();

    if (!mounted) return;

    if (resultado.containsKey('error')) {
      HapticFeedback.heavyImpact(); // Feedback táctil de error
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
          margin: const EdgeInsets.all(16),
        ),
      );
    } else if (resultado['exito'] == true) {
      HapticFeedback.mediumImpact(); // Feedback de éxito

      final String rol = resultado['rol'];
      final Map<String, dynamic> dashboardData = resultado['dashboard'];

      if (rol == 'operador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChoferScreen(userData: dashboardData),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainWrapperScreen(userData: dashboardData),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F7FA,
      ), // Mismo fondo limpio que tu historial
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 72,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'RUTAPA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rutas para todos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Formulario de inicio de sesión
                    _buildTextField(
                      controller: _controller.identificadorCtrl,
                      label: 'Correo o Teléfono',
                      icon: Icons.person_rounded,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_controller.isLoading,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _controller.passwordCtrl,
                      label: 'Contraseña',
                      icon: Icons.lock_rounded,
                      obscureText: _controller.ocultarPassword,
                      enabled: !_controller.isLoading,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _controller.ocultarPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: _controller.togglePasswordVisibility,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón de inicio de sesión con animación y feedback táctil
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _controller.isLoading
                            ? null
                            : _procesarLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.blueAccent.withValues(
                            alpha: 0.6,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _controller.isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Enlace para registro
                    TextButton(
                      onPressed: _controller.isLoading
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistroScreen(),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          text: '¿No tienes cuenta? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Regístrate aquí',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Inputs personalizados para mantener la consistencia visual y funcional
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
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
      ),
    );
  }
}
