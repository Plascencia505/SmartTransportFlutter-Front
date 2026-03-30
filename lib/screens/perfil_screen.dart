import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/perfil_controller.dart';

class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PerfilScreen({super.key, required this.userData});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late PerfilController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PerfilController(widget.userData);
  }

  void _confirmarCerrarSesion() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (contextDialog) => AlertDialog(
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialog),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(contextDialog);
              _controller.cerrarSesion(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 NUEVO: Envolvemos en ListenableBuilder
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final user = _controller.userData;
        final bool cargando = _controller.isLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mi Perfil',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    '${user['nombres']} ${user['apellidos']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Tarjetas de Información Dinámicas
                  _construirTarjetaInfo(
                    Icons.email_outlined,
                    'Correo Electrónico',
                    cargando
                        ? 'Cargando...'
                        : (user['correo'] ?? user['email'] ?? 'No disponible'),
                  ),
                  _construirTarjetaInfo(
                    Icons.phone_outlined,
                    'Teléfono',
                    cargando
                        ? 'Cargando...'
                        : (user['telefono'] ?? 'No disponible'),
                  ),
                  _construirTarjetaInfo(
                    Icons.badge_outlined,
                    'CURP',
                    cargando
                        ? 'Cargando...'
                        : (user['curp'] ?? 'No disponible'),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _confirmarCerrarSesion,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirTarjetaInfo(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    // Si dice cargando, lo ponemos en gris, si no, negro
                    fontWeight: value == 'Cargando...'
                        ? FontWeight.normal
                        : FontWeight.w600,
                    fontSize: 15,
                    color: value == 'Cargando...'
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
