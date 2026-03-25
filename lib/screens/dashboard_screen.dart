import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/services/api_service.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:otp/otp.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late double _saldoActual;
  late int _boletosActuales;
  bool _isLoading = false;

  late io.Socket socket;
  Timer? _timerSincronizacion;
  Timer? _timerPeriodico;
  String _codigoTotpActual = '';

  @override
  void initState() {
    super.initState();
    _saldoActual = (widget.userData['saldo'] ?? 0).toDouble();
    _boletosActuales = widget.userData['boletosDisponibles'] ?? 0;

    _conectarSocket();
    _iniciarMotorTOTP();
  }

  // --- Sincronización Matemática del QR ---
  void _iniciarMotorTOTP() {
    _generarCodigoTOTP();
    final int ahora = DateTime.now().millisecondsSinceEpoch;
    final int msFaltantes = 30000 - (ahora % 30000);

    _timerSincronizacion = Timer(Duration(milliseconds: msFaltantes), () {
      if (mounted) {
        _generarCodigoTOTP();
        _timerPeriodico = Timer.periodic(const Duration(seconds: 30), (timer) {
          if (mounted) _generarCodigoTOTP();
        });
      }
    });
  }

  void _generarCodigoTOTP() {
    final String semilla =
        widget.userData['totpSecret']?.toString().trim() ?? '';
    if (semilla.isEmpty) return;

    final String nuevoCodigo = OTP.generateTOTPCodeString(
      semilla,
      DateTime.now().millisecondsSinceEpoch,
      length: 6,
      interval: 30,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );

    setState(() {
      _codigoTotpActual = nuevoCodigo;
    });
  }

  // --- Sockets ---
  void _conectarSocket() {
    String socketUrl = ApiService.baseUrl.replaceAll('/api', '');

    socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Conectado al servidor de Sockets');
      socket.emit('unirse_canal', widget.userData['id']);
    });

    socket.on('boleto_cobrado', (data) {
      if (data['idPasajero'] == widget.userData['id']) {
        if (mounted) {
          setState(() {
            _boletosActuales = data['boletosRestantes'];
          });
          _mostrarTicketModerno(data['boletosRestantes']);
        }
      }
    });
  }

  void _mostrarTicketModerno(int boletosRestantes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Viaje Pagado!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te quedan $boletosRestantes boletos',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _timerSincronizacion?.cancel();
    _timerPeriodico?.cancel();
    super.dispose();
  }

  Widget _construirAreaCentral() {
    if (_boletosActuales <= 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin Boletos Disponibles',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Necesitas adquirir boletos en el módulo\nde compra para poder abordar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    // Si tiene boletos pero el código aún carga
    if (_codigoTotpActual.isEmpty) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Si todo está bien, mostramos el QR dinámico
    final datosQR = jsonEncode({
      'idPasajero': widget.userData['id'],
      'totp': _codigoTotpActual,
    });

    return QrImageView(
      data: datosQR,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
    );
  }

  Future<void> _ejecutarRecarga(double monto) async {
    setState(() => _isLoading = true);
    final result = await ApiService.recargarSaldo(widget.userData['id'], monto);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      setState(() => _saldoActual = (result['saldoActual']).toDouble());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recarga exitosa'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _ejecutarCompra(int cantidad, double costoTotal) async {
    setState(() => _isLoading = true);
    final result = await ApiService.comprarBoletos(
      widget.userData['id'],
      cantidad,
      costoTotal,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      setState(() {
        // Devuelve boletos disponibles
        _boletosActuales =
            result['boletosDisponibles'] ?? result['boletosActuales'];
        _saldoActual = (result['saldoRestante']).toDouble();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compra exitosa'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _mostrarDialogoRecarga() {
    final TextEditingController montoCtrl = TextEditingController(text: "50");
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recargar Saldo (Simulador)'),
        content: TextField(
          controller: montoCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monto a recargar (\$)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final double monto = double.tryParse(montoCtrl.text) ?? 0;
              Navigator.pop(dialogContext);
              if (monto > 0) _ejecutarRecarga(monto);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCompra() {
    final TextEditingController cantidadCtrl = TextEditingController(text: "1");
    final double tarifa = widget.userData['aplicaDescuento'] == true
        ? 6.0
        : 12.0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final int cantidad = int.tryParse(cantidadCtrl.text) ?? 0;
            final double total = cantidad * tarifa;
            final bool excedeSaldo = total > _saldoActual;

            return AlertDialog(
              title: const Text('Comprar Boletos'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tarifa aplicable: \$${tarifa.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: cantidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Total a pagar: \$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: excedeSaldo
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: excedeSaldo ? Colors.red : Colors.black,
                    ),
                  ),
                  if (excedeSaldo)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Excede tu saldo actual',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (excedeSaldo || cantidad <= 0)
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _ejecutarCompra(cantidad, total);
                        },
                  child: const Text('Pagar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Mi Billetera',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              const storage = FlutterSecureStorage();
              await storage.deleteAll();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Hola, ${widget.userData['nombres']}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.userData['aplicaDescuento'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Chip(
                        label: Text('Tarifa Preferencial Activa (50%)'),
                        backgroundColor: Colors.greenAccent,
                      ),
                    ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2, // Sombra suave profesional
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24.0,
                        horizontal: 20.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Saldo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\$${_saldoActual.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 50,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          Column(
                            children: [
                              Text(
                                'Boletos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$_boletosActuales',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Título dinámico sobrio
                  Text(
                    _boletosActuales > 0
                        ? 'Tu Código de Abordaje'
                        : 'Estado de Cuenta',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    width: 250,
                    height: 250,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(child: _construirAreaCentral()),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _mostrarDialogoRecarga,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_card,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Recargar',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _mostrarDialogoCompra,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade700,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.confirmation_number, size: 20),
                          label: const Text(
                            'Comprar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
