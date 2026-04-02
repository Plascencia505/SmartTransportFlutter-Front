import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';

class DbOfflineService {
  // Patrón Singleton
  static final DbOfflineService _instancia = DbOfflineService._interno();
  factory DbOfflineService() => _instancia;
  DbOfflineService._interno();

  static Database? _database;

  // Getter que inicializa la DB la primera vez que se llama
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('validador_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Abre (o crea) la base de datos
    return await openDatabase(path, version: 1, onCreate: _crearDB);
  }

  // Se ejecuta solo la primera vez que se instala la app del chofer
  Future<void> _crearDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE viajes_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idPasajero TEXT NOT NULL,
        totpScaneado TEXT NOT NULL,
        fechaHoraEscaneo TEXT NOT NULL,
        estatus TEXT NOT NULL DEFAULT 'pendiente'
      )
    ''');
    debugPrint('🗄️ SQLite: Tabla "viajes_pendientes" creada con éxito.');
  }

  // OPERACIONES DEL VALIDADOR OFFLINE
  /// Guarda un código QR escaneado cuando no hay internet
  Future<int> guardarViajePendiente(String idPasajero, String totp) async {
    final db = await database;

    // Esta fechaHoraEscaneo es nuestra "Máquina del tiempo" para el backend
    final data = {
      'idPasajero': idPasajero,
      'totpScaneado': totp,
      'fechaHoraEscaneo': DateTime.now().toIso8601String(),
      'estatus': 'pendiente',
    };

    final id = await db.insert('viajes_pendientes', data);
    debugPrint('💾 SQLite: Viaje offline guardado en bóveda local con ID $id');
    return id;
  }

  /// Recupera todos los viajes atrapados en el teléfono para enviarlos
  Future<List<Map<String, dynamic>>> obtenerViajesPendientes() async {
    final db = await database;
    return await db.query(
      'viajes_pendientes',
      where: 'estatus = ?',
      whereArgs: ['pendiente'],
    );
  }

  /// Limpia la bóveda una vez que el backend confirma que los recibió
  Future<void> borrarViajesSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    // Genera los signos de interrogación necesarios: (?, ?, ?)
    final placeholders = List.filled(ids.length, '?').join(',');

    await db.delete(
      'viajes_pendientes',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    debugPrint(
      '🧹 SQLite: Bóveda limpiada. ${ids.length} viajes borrados tras sincronización.',
    );
  }
}
