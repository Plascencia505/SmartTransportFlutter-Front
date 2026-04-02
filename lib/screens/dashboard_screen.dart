import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:transporte_app/controllers/dashboard_controller.dart';
import 'package:shimmer/shimmer.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(widget.userData);

    WidgetsBinding.instance.addObserver(this);

    // Receptor del socket
    _controller.onBoletoCobradoCallback = (boletosRestantes, mensaje) {
      if (!mounted) return;
      _mostrarTicketModerno(boletosRestantes, mensaje);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.generarBoletoSeguro();
    }
  }

  // 2. MODAL ACTUALIZADO PARA MOSTRAR EL MENSAJE OFFLINE/ONLINE
  void _mostrarTicketModerno(int boletosRestantes, String mensaje) {
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
                  '¡Cobro Registrado!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mensaje, // <-- Aquí dice si fue online o diferido
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te quedan $boletosRestantes boletos',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
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
                            HapticFeedback.heavyImpact();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['error']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            HapticFeedback.mediumImpact();
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
                            HapticFeedback.heavyImpact();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(result['error']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            HapticFeedback.mediumImpact();
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

  Widget _construirSaldoText(double saldo) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final parts = formatter.format(saldo).split('.');
    final enteros = parts[0];
    final centavos = parts[1];

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
        children: [
          const TextSpan(text: '\$', style: TextStyle(fontSize: 18)),
          TextSpan(text: enteros, style: const TextStyle(fontSize: 28)),
          TextSpan(text: '.$centavos', style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _construirAreaCentral() {
    if (_controller.boletosActuales <= -4) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block_flipped, size: 45, color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text(
            'Adeudo Máximo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Llegaste al límite de 4 viajes a crédito.\nRecarga para seguir viajando.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    // 3. ACTUALIZADO AL NUEVO NOMBRE DE VARIABLE Y SIN JSONENCODE MANUAL
    if (_controller.codigoQRActual.isEmpty) {
      return _dibujarShimmer(180, 180);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        QrImageView(
          data: _controller.codigoQRActual, // <-- Directo del controlador
          version: QrVersions.auto,
          size: 180.0,
          backgroundColor: Colors.white,
        ),
        if (_controller.boletosActuales <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Viajando a crédito (${_controller.boletosActuales.abs()}/4)',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  String _formatearFecha(String fechaIso) {
    try {
      final fecha = DateTime.parse(fechaIso).toLocal();
      return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} • ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return fechaIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext builderContext, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: Colors.blueAccent,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    _controller
                        .generarBoletoSeguro(); // Regeneramos el QR al hacer pull-to-refresh
                    final error = await _controller.recargaSilenciosa();
                    if (error != null && builderContext.mounted) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            error,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: Colors.grey.shade800,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: 60.0,
                      left: 20.0,
                      right: 20.0,
                      bottom: 40.0,
                    ),
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

                        // Tarjeta de Saldo y Boletos
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24.0,
                              horizontal: 20.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Boletos
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
                                Container(
                                  height: 50,
                                  width: 1,
                                  color: Colors.grey.shade200,
                                ),
                                // Saldo
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
                                        : _construirSaldoText(
                                            _controller.saldoActual,
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

                        // Mini-historial del último viaje
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _controller.ultimoViaje == null
                                    ? 'Sin viajes por el momento'
                                    : 'Último viaje: ${_formatearFecha(_controller.ultimoViaje!['fecha'])}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Botones de acción
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _mostrarDialogoRecarga();
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add_card, size: 20),
                                label: const Text(
                                  'Recargar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _mostrarDialogoCompra();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 1,
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
                ),
        );
      },
    );
  }
}
