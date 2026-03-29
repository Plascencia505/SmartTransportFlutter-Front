import 'package:flutter/material.dart';
import 'package:transporte_app/controllers/historial_controller.dart';

class HistorialScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HistorialScreen({super.key, required this.userData});

  @override
  State<HistorialScreen> createState() => HistorialScreenState();
}

class HistorialScreenState extends State<HistorialScreen> {
  late HistorialController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HistorialController(widget.userData);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Este método existe para que el MainWrapperScreen pueda forzar la recarga mediante la GlobalKey
  void cargarHistorialPublico() {
    _controller.cargarHistorialPublico();
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
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              'Movimientos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtros de tipo de movimiento
              Container(
                padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                  ),
                ),
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _crearChip('Todos', 'todos'),
                      const SizedBox(width: 10),
                      _crearChip('Viajes', 'viaje'),
                      const SizedBox(width: 10),
                      _crearChip('Recargas', 'recarga'),
                      const SizedBox(width: 10),
                      _crearChip('Compras', 'compra'),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),

              // Lista de movimientos
              Expanded(
                child: _controller.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : _controller.error.isNotEmpty
                    ? Center(
                        child: Text(
                          _controller.error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _controller.historialFiltrado.isEmpty
                    ? _estadoVacio()
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: _controller.historialFiltrado.length,
                        itemBuilder: (context, index) {
                          final item = _controller.historialFiltrado[index];
                          return _construirTarjetaHistorial(item);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // widget para crear los chips de filtro, con animación y estilos personalizados

  Widget _crearChip(String etiqueta, String valorFiltro) {
    final bool seleccionado = _controller.filtroActual == valorFiltro;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ChoiceChip(
        label: Text(
          etiqueta,
          style: TextStyle(
            color: seleccionado ? Colors.white : Colors.black87,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: seleccionado,
        selectedColor: Colors.blueAccent,
        backgroundColor: Colors.grey.shade100,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: seleccionado ? Colors.blueAccent : Colors.grey.shade300,
            width: 1,
          ),
        ),
        onSelected: (bool selected) {
          if (selected) {
            _controller.cambiarFiltro(valorFiltro);
          }
        },
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aún no hay movimientos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus viajes y recargas aparecerán aquí.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaHistorial(Map<String, dynamic> item) {
    IconData icono;
    Color colorIcono;
    Color colorFondoIcono;
    String trailingText;
    Color trailingColor;

    if (item['tipo'] == 'recarga') {
      icono = Icons.add_card_rounded;
      colorIcono = const Color(0xFF00BFA5);
      colorFondoIcono = const Color(0xFFE0F2F1);
      trailingText = '+\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = const Color(0xFF00BFA5);
    } else if (item['tipo'] == 'compra') {
      icono = Icons.confirmation_num_rounded;
      colorIcono = const Color(0xFFFF9800);
      colorFondoIcono = const Color(0xFFFFF3E0);
      trailingText = '-\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = Colors.black87;
    } else {
      icono = Icons.directions_bus_rounded;
      colorIcono = Colors.blueAccent;
      colorFondoIcono = const Color(0xFFE3F2FD);
      trailingText = item['etiquetaExtra'] ?? 'Completado';
      trailingColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorFondoIcono,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: colorIcono, size: 24),
        ),
        title: Text(
          item['titulo'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['subtitulo'] ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatearFecha(item['fecha']),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: Text(
          trailingText,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: trailingColor,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
