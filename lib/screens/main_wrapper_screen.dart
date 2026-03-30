import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:transporte_app/screens/dashboard_screen.dart';
import 'package:transporte_app/screens/historial_screen.dart';

class MainWrapperScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MainWrapperScreen({super.key, required this.userData});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  int _indiceActual = 0;
  late List<Widget> _pantallas;

  final GlobalKey<HistorialScreenState> _historialKey =
      GlobalKey<HistorialScreenState>();

  // Banderas y variables para el monitor de red
  late StreamSubscription<List<ConnectivityResult>> _suscripcionRed;
  bool _sinConexion = false;
  bool _mostrarRestablecido = false;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      DashboardScreen(userData: widget.userData),
      HistorialScreen(key: _historialKey, userData: widget.userData),
    ];

    // Iniciamos el monitor de red
    _iniciarMonitorDeRed();
  }

  void _iniciarMonitorDeRed() async {
    // Revisamos el estado inicial de la conexión para mostrar el cintillo correcto desde el principio
    final estadoInicial = await Connectivity().checkConnectivity();
    _procesarCambioDeRed(estadoInicial);

    // Escuchamos los cambios de red para actualizar el estado en tiempo real
    _suscripcionRed = Connectivity().onConnectivityChanged.listen(
      _procesarCambioDeRed,
    );
  }

  void _procesarCambioDeRed(List<ConnectivityResult> resultados) {
    // La nueva versión del paquete devuelve una lista. Si todos son "none", no hay internet.
    final noHayInternet = resultados.every((r) => r == ConnectivityResult.none);

    if (noHayInternet && !_sinConexion) {
      if (mounted) {
        setState(() {
          _sinConexion = true;
          _mostrarRestablecido = false;
        });
      }
    } else if (!noHayInternet && _sinConexion) {
      if (mounted) {
        setState(() {
          _sinConexion = false;
          _mostrarRestablecido = true;
        });

        // ocultar luego de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _mostrarRestablecido = false);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _suscripcionRed
        .cancel(); // Detenemos el monitor de red para ahorrar recursos y evitar fugas de memoria
    super.dispose();
  }

  // cintillo rojo/verde de conexión
  Widget _construirCintilloRed() {
    final bool mostrarCintillo = _sinConexion || _mostrarRestablecido;
    final Color colorFondo = _sinConexion
        ? Colors.red.shade600
        : Colors.green.shade600;
    final String texto = _sinConexion
        ? 'Sin conexión a Internet'
        : 'Conexión restablecida';
    final IconData icono = _sinConexion
        ? Icons.wifi_off_rounded
        : Icons.wifi_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      height: mostrarCintillo ? 32 : 0, // Se oculta encogiendo su altura a 0
      width: double.infinity,
      color: colorFondo,
      child: SingleChildScrollView(
        physics:
            const NeverScrollableScrollPhysics(), // Evita errores visuales al animar
        child: SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Envolvemos el cintillo en SafeArea solo por arriba para que no lo tape el "Notch" de la cámara
          SafeArea(bottom: false, child: _construirCintilloRed()),
          Expanded(
            child: IndexedStack(index: _indiceActual, children: _pantallas),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });

          if (index == 1) {
            Future.delayed(const Duration(milliseconds: 100), () {
              _historialKey.currentState?.cargarHistorialPublico();
            });
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey.shade400,
        elevation: 16,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Billetera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}
