import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:transporte_app/services/api_service.dart';

class HistorialScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HistorialScreen({super.key, required this.userData});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  bool _isLoading = true;
  String _error = '';
  List<dynamic> _historialCompleto = [];
  List<dynamic> _historialFiltrado = [];
  String _filtroActual = 'todos';

  late io.Socket socket; // ¡Nuestro nuevo vigilante en tiempo real!

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _conectarSocket(); // Encendemos el radar
  }

  // --- LA MAGIA EN TIEMPO REAL ---
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

    // Cuando el chofer escanea tu QR, el backend grita 'boleto_cobrado'.
    // ¡Lo escuchamos y recargamos el historial en silencio!
    socket.on('boleto_cobrado', (data) {
      if (mounted) {
        _cargarHistorial();
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    // Si ya hay datos, no mostramos el loader circular para no molestar al usuario en la recarga por sockets
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
        // Reaplicamos el filtro actual por si el usuario estaba viendo solo "Viajes"
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
      return "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return fechaIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Movimientos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(
                () => _historialCompleto.clear(),
              ); // Forzamos el loader manual
              _cargarHistorial();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _crearChip('Todos', 'todos'),
                  const SizedBox(width: 8),
                  _crearChip('Viajes', 'viaje'),
                  const SizedBox(width: 8),
                  _crearChip('Recargas', 'recarga'),
                  const SizedBox(width: 8),
                  _crearChip('Compras', 'compra'),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _historialFiltrado.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay movimientos aquí',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
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

  Widget _crearChip(String etiqueta, String valorFiltro) {
    final bool seleccionado = _filtroActual == valorFiltro;
    return ChoiceChip(
      label: Text(
        etiqueta,
        style: TextStyle(
          color: seleccionado ? Colors.white : Colors.black87,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: seleccionado,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool selected) {
        if (selected) _aplicarFiltro(valorFiltro);
      },
    );
  }

  Widget _construirTarjetaHistorial(Map<String, dynamic> item) {
    IconData icono;
    Color colorIcono;
    String trailingText;
    Color trailingColor;

    if (item['tipo'] == 'recarga') {
      icono = Icons.add_circle_outline;
      colorIcono = Colors.green;
      trailingText = '+\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = Colors.green;
    } else if (item['tipo'] == 'compra') {
      icono = Icons.confirmation_number_outlined;
      colorIcono = Colors.orange;
      trailingText = '-\$${item['monto'].abs().toStringAsFixed(2)}';
      trailingColor = Colors.red;
    } else {
      // Es viaje (Ahora se ve más limpio sin el "-1 Boleto")
      icono = Icons.directions_bus_outlined;
      colorIcono = Colors.blueAccent;
      trailingText = item['etiquetaExtra'] ?? 'Completado';
      trailingColor = Colors
          .blueAccent; // Lo pusimos azul para que parezca una insignia de éxito
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorIcono.withOpacity(0.15),
          radius: 24,
          child: Icon(icono, color: colorIcono, size: 28),
        ),
        title: Text(
          item['titulo'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['subtitulo'] ?? '',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _formatearFecha(item['fecha']),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ],
          ),
        ),
        trailing: Text(
          trailingText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: trailingColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
