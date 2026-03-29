import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transporte_app/screens/login_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:transporte_app/controllers/dashboard_controller.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(widget.userData);

    _controller.onBoletoCobradoCallback = (boletosRestantes) {
      if (!mounted) return;
      _mostrarTicketModerno(boletosRestantes);
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  void _mostrarDialogoRecarga() {
    final TextEditingController montoCtrl = TextEditingController(text: "50");

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            final double monto = double.tryParse(montoCtrl.text) ?? 0;
            final bool excedeLimite = monto > _controller.limiteMaxRecarga;

            return AlertDialog(
              title: const Text('Recargar Saldo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Monto a recargar (\$)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setStateDialog(() {}),
                  ),
                  if (excedeLimite)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        'Máximo \$${_controller.limiteMaxRecarga.toStringAsFixed(2)} por recarga',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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
                  onPressed: (monto <= 0 || excedeLimite)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(dialogContext);
                          final result = await _controller.ejecutarRecarga(
                            monto,
                          );
                          if (result.containsKey('error')) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['error']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Recarga exitosa'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
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
          builder: (contextDialog, setStateDialog) {
            final int cantidad = int.tryParse(cantidadCtrl.text) ?? 0;
            final double total = cantidad * tarifa;
            final bool excedeSaldo = total > _controller.saldoActual;
            final bool excedeLimiteBoletos =
                cantidad > _controller.limiteMaxBoletos;

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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                  if (excedeLimiteBoletos)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Máximo ${_controller.limiteMaxBoletos} boletos por compra',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
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
                  onPressed:
                      (excedeSaldo || cantidad <= 0 || excedeLimiteBoletos)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(dialogContext);
                          final result = await _controller.ejecutarCompra(
                            cantidad,
                            total,
                          );
                          if (result.containsKey('error')) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['error']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Compra exitosa'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
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

  Widget _dibujarShimmer(double ancho, double alto) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  // Area principal del dashboard, muestra el QR o mensaje de sin boletos
  Widget _construirAreaCentral() {
    if (_controller.boletosActuales <= 0) {
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

    if (_controller.codigoTotpActual.isEmpty) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final datosQR = jsonEncode({
      'idPasajero': widget.userData['id'],
      'totp': _controller.codigoTotpActual,
    });

    return QrImageView(
      data: datosQR,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext builderContext, Widget? child) {
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
                  final navigator = Navigator.of(builderContext);

                  const storage = FlutterSecureStorage();
                  await storage.deleteAll();
                  navigator.pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _controller.isLoading
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
                        elevation: 2,
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
                                  _controller.isSyncing
                                      ? _dibujarShimmer(80, 30)
                                      : Text(
                                          '\$${_controller.saldoActual.toStringAsFixed(2)}',
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
                                  _controller.isSyncing
                                      ? _dibujarShimmer(40, 30)
                                      : Text(
                                          '${_controller.boletosActuales}',
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
                      Text(
                        _controller.boletosActuales > 0
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.confirmation_number,
                                size: 20,
                              ),
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
      },
    );
  }
}
