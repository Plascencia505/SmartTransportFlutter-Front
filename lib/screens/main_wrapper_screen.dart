import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:transporte_app/screens/dashboard_screen.dart';
import 'package:transporte_app/screens/historial_screen.dart';
import 'package:transporte_app/screens/perfil_screen.dart';

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

  late StreamSubscription<List<ConnectivityResult>> _suscripcionRed;
  bool _sinConexion = false;
  bool _mostrarRestablecido = false;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      DashboardScreen(userData: widget.userData),
      HistorialScreen(key: _historialKey, userData: widget.userData),
      PerfilScreen(userData: widget.userData),
    ];
    _iniciarMonitorDeRed();
  }

  void _iniciarMonitorDeRed() async {
    final estadoInicial = await Connectivity().checkConnectivity();
    _procesarCambioDeRed(estadoInicial);
    _suscripcionRed = Connectivity().onConnectivityChanged.listen(
      _procesarCambioDeRed,
    );
  }

  void _procesarCambioDeRed(List<ConnectivityResult> resultados) {
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
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _mostrarRestablecido = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _suscripcionRed.cancel();
    super.dispose();
  }

  // pill para mostrar el estado de la conexión (sin conexión o restablecida)
  Widget _construirPildoraRed() {
    final bool mostrarCintillo = _sinConexion || _mostrarRestablecido;
    final Color colorFondo = Colors.black87;
    final String texto = _sinConexion
        ? 'Sin conexión'
        : 'Conexión restablecida';
    final IconData icono = _sinConexion
        ? Icons.wifi_off_rounded
        : Icons.wifi_rounded;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: mostrarCintillo ? 50.0 : -60.0,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: mostrarCintillo ? 1.0 : 0.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  texto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(index: _indiceActual, children: _pantallas),
          _construirPildoraRed(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
