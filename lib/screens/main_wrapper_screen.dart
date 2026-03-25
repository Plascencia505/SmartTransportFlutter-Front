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

  @override
  void initState() {
    super.initState();
    // Aquí inicializamos las pantallas y les inyectamos los datos del usuario
    _pantallas = [
      DashboardScreen(userData: widget.userData),
      HistorialScreen(userData: widget.userData),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene vivo el estado de los Sockets y el QR del Dashboard
      body: IndexedStack(index: _indiceActual, children: _pantallas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });
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
