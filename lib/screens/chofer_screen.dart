import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/operador_controller.dart';
import 'package:transporte_app/services/sync_worker_service.dart';

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
    SyncWorkerService().iniciarVigilante(widget.userData['id']);

    // Escuchamos al Mensajero: Si termina de sincronizar, le decimos al controlador que cuente de nuevo
    SyncWorkerService().addListener(_onSyncWorkerUpdate);
  }

  void _onSyncWorkerUpdate() {
    // Si el mensajero dejó de trabajar (terminó de subir datos), actualizamos el contador visual
    if (!SyncWorkerService().isSyncing) {
      _controller.cargarPendientes();
    }
  }

  Future<void> _procesarQR(BarcodeCapture capture) async {
    if (_controller.isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? codigo = barcodes.first.rawValue;
    if (codigo == null) return;

    // Pausar cámara de inmediato
    cameraController.stop();

    // Mandar al cerebro
    final resultado = await _controller.procesarBoleto(codigo);
    if (!mounted) return;

    int tiempoDePausa = 2;

    switch (resultado['status']) {
      case 'online_success':
        HapticFeedback.heavyImpact();
        _mostrarMensaje(resultado['message'], Colors.green, Icons.cloud_done);
        tiempoDePausa = 2;
        break;
      case 'offline_success':
        HapticFeedback.mediumImpact();
        _mostrarMensaje(resultado['message'], Colors.teal, Icons.sd_storage);
        tiempoDePausa = 3;
        break;
      case 'error': // Fraude o error del backend
        HapticFeedback.vibrate();
        _mostrarMensaje(resultado['message'], Colors.red, Icons.cancel);
        tiempoDePausa = 4; //pausa más larga
        break;
      case 'invalid_qr':
        _mostrarMensaje(
          resultado['message'],
          Colors.orange,
          Icons.qr_code_scanner,
        );
        tiempoDePausa = 3;
        break;
    }

    // Esperamos los segundos dictados por la gravedad del asunto
    await Future.delayed(Duration(seconds: tiempoDePausa));
    if (mounted && resultado['status'] != 'ignored') {
      cameraController.start();
    }
  }

  void _mostrarMensaje(String texto, Color color, IconData icono) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    SyncWorkerService().removeListener(_onSyncWorkerUpdate);
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
            title: Text(widget.userData['nombres']),
            actions: [
              //Contador de viajes offline + indicador de sincronización
              ListenableBuilder(
                listenable: SyncWorkerService(),
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        // Contador de viajes offline
                        if (_controller.pendientesCount > 0) ...[
                          const Icon(
                            Icons.sd_card,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_controller.pendientesCount}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Indicador animado de subida a la nube
                        SyncWorkerService().isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.cloud_done_rounded,
                                // Se pinta gris si hay pendientes y verde si está limpio
                                color: _controller.pendientesCount > 0
                                    ? Colors.white38
                                    : Colors.greenAccent,
                              ),
                      ],
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  SyncWorkerService().detenerVigilante();
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
                    // Filtro visual oscuro
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
