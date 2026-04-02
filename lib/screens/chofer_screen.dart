import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/operador_controller.dart';

class ChoferScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChoferScreen({super.key, required this.userData});

  @override
  State<ChoferScreen> createState() => _ChoferScreenState();
}

class _ChoferScreenState extends State<ChoferScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  late OperadorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OperadorController(widget.userData);
  }

  Future<void> _procesarQR(BarcodeCapture capture) async {
    if (_controller.isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? codigo = barcodes.first.rawValue;
    if (codigo == null) return;

    // Pausar cámara mientras se procesa
    cameraController.stop();

    // Le pasamos el QR crudo al cerebro
    final resultado = await _controller.procesarBoleto(codigo);

    if (!mounted) return;

    // Evaluamos qué nos dijo el controlador
    switch (resultado['status']) {
      case 'online_success':
        HapticFeedback.heavyImpact();
        _mostrarMensaje(resultado['message'], Colors.green);
        break;
      case 'offline_success':
        HapticFeedback.mediumImpact();
        //Diferenciamos el mensaje offline con un color distinto
        _mostrarMensaje(resultado['message'], Colors.teal);
        break;
      case 'error':
        HapticFeedback.vibrate(); // Error
        _mostrarMensaje(resultado['message'], Colors.red);
        break;
      case 'invalid_qr':
        _mostrarMensaje(resultado['message'], Colors.orange);
        break;
    }

    // Esperamos 2 segundos antes de volver a activar la cámara para el siguiente pasajero
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && resultado['status'] != 'ignored') {
      cameraController.start();
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Unidad - ${widget.userData['nombres']}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  const storage = FlutterSecureStorage();
                  await storage.deleteAll();

                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.blueAccent.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(16.0),
                child: const Text(
                  'Apunta la cámara al código del pasajero',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: cameraController,
                      onDetect: _procesarQR,
                    ),
                    // Filtro visual oscuro y loading
                    if (_controller.isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 4,
                          ),
                        ),
                      ),
                    // Mira central para apuntar
                    if (!_controller.isProcessing)
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
