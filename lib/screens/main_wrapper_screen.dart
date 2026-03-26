import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _pantallas = [
      DashboardScreen(userData: widget.userData),
      HistorialScreen(key: _historialKey, userData: widget.userData),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceActual, children: _pantallas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });

          // 3. Si el usuario toca la pestaña del Historial (índice 1)...
          if (index == 1) {
            // ...obligamos a la pantalla a ejecutar su función de recarga silenciosa
            // Usamos un pequeño delay para que la animación de la pestaña sea fluida primero
            Future.delayed(const Duration(milliseconds: 100), () {
              // Aquí llamamos a la función que le quitaste el guion bajo
              _historialKey.currentState?.cargarHistorialPublico();
            });
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey.shade400,
        elevation: 8,
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
