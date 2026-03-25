import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChoferScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChoferScreen({super.key, required this.userData});

  @override
  State<ChoferScreen> createState() => _ChoferScreenState();
}

class _ChoferScreenState extends State<ChoferScreen> {
  // Controlador para manejar la cámara
  final MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _procesarQR(BarcodeCapture capture) async {
    // Si ya estamos procesando un pago, ignoramos lo que siga leyendo la cámara
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? codigo = barcodes.first.rawValue;
    if (codigo == null) return;

    // Detenemos visualmente la lectura
    setState(() => _isProcessing = true);
    cameraController.stop();

    try {
      // Decodificamos el JSON que viene en el QR para obtener el ID del pasajero
      final Map<String, dynamic> dataQR = jsonDecode(codigo);
      final String idPasajero = dataQR['idPasajero'];
      final String totp = dataQR['totp']; // Obtenemos el TOTP del QR

      // Mandamos llamar a nuestro backend
      final result = await ApiService.utilizarBoleto(
        idPasajero,
        widget.userData['id'],
        totp,
      );

      if (!mounted) return;

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pasaje Validado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Si escanean un QR que no es de tu app
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Inválido'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // Esperamos 2 segundos antes de volver a activar la cámara para el siguiente pasajero
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
      cameraController.start();
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unidad - ${widget.userData['nombres']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              const storage = FlutterSecureStorage();
              await storage
                  .deleteAll(); // Borra todos los datos guardados, incluyendo el token y los datos del usuario

              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Apunta la cámara al código del pasajero',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                // Un filtro visual oscuro para que el chofer sepa que está cargando
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
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
