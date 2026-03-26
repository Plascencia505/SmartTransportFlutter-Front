import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:transporte_app/services/api_service.dart';

class HistorialScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HistorialScreen({super.key, required this.userData});

  @override
  State<HistorialScreen> createState() => HistorialScreenState();
}

class HistorialScreenState extends State<HistorialScreen> {
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _historialCompleto = [];
  List<dynamic> _historialFiltrado = [];
  String _filtroActual = 'todos';

  late io.Socket socket;

  @override
  void initState() {
    super.initState();
    cargarHistorialPublico();
    _conectarSocket();
  }

  void _conectarSocket() {
    String socketUrl = ApiService.baseUrl.replaceAll('/api', '');

    socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      final idUsuario = widget.userData['id'] ?? widget.userData['_id'];
      socket.emit('unirse_canal', idUsuario);
    });

    socket.on('boleto_cobrado', (data) {
      if (mounted) cargarHistorialPublico();
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> cargarHistorialPublico() async {
    if (_historialCompleto.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    final idUsuario = widget.userData['id'] ?? widget.userData['_id'];
    final result = await ApiService.obtenerHistorial(idUsuario);

    if (!mounted) return;

    if (result.containsKey('error')) {
      setState(() {
        _error = result['error'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _historialCompleto = result['historial'] ?? [];
        _aplicarFiltro(_filtroActual);
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltro(String filtro) {
    setState(() {
      _filtroActual = filtro;
      if (filtro == 'todos') {
        _historialFiltrado = List.from(_historialCompleto);
      } else {
        _historialFiltrado = _historialCompleto
            .where((item) => item['tipo'] == filtro)
            .toList();
      }
    });
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                : _error.isNotEmpty
                ? Center(
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _historialFiltrado.isEmpty
                ? _estadoVacio()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _historialFiltrado.length,
                    itemBuilder: (context, index) {
                      final item = _historialFiltrado[index];
                      return _construirTarjetaHistorial(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE DISEÑO ---

  Widget _crearChip(String etiqueta, String valorFiltro) {
    final bool seleccionado = _filtroActual == valorFiltro;
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
          if (selected) _aplicarFiltro(valorFiltro);
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
      colorIcono = const Color(0xFF00BFA5); // Verde azulado para recargas
      colorFondoIcono = const Color(0xFFE0F2F1); // Fondo suave para recargas
      trailingText = '+\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = const Color(0xFF00BFA5); // Mismo verde para el texto
    } else if (item['tipo'] == 'compra') {
      icono = Icons.confirmation_num_rounded;
      colorIcono = const Color(0xFFFF9800); // Naranja para compras de boletos
      colorFondoIcono = const Color(0xFFFFF3E0); // Fondo suave para compras
      trailingText = '-\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = Colors
          .black87; // Color neutro para compras, ya que el monto es pequeño y el foco es el ícono
    } else {
      icono = Icons.directions_bus_rounded;
      colorIcono =
          Colors.blueAccent; // Azul para viajes, el ícono más importante
      colorFondoIcono = const Color(0xFFE3F2FD); // Fondo suave para viajes
      trailingText = item['etiquetaExtra'] ?? 'Completado';
      trailingColor = Colors
          .blueAccent; // Mismo azul para el texto, ya que el foco es el ícono y el texto es secundario
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
