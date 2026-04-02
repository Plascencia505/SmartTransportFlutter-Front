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
    _database = await _initDB(
      'validador_offline_v2.db',
    ); // Cambiamos el nombre para forzar limpieza si es necesario
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Subimos la versión a 2 por el cambio de esquema
    return await openDatabase(
      path,
      version: 2,
      onCreate: _crearDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        // Si ya existía la versión 1, borramos la tabla vieja para no tener conflictos
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS viajes_pendientes');
          await _crearDB(db, newVersion);
        }
      },
    );
  }

  // Se ejecuta al crear la base de datos
  Future<void> _crearDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE viajes_pendientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idPasajero TEXT NOT NULL,
        idBoleto TEXT NOT NULL,
        firma TEXT NOT NULL,
        fechaHoraEscaneo TEXT NOT NULL,
        estatus TEXT NOT NULL DEFAULT 'pendiente'
      )
    ''');
    debugPrint('SQLite: Tabla "viajes_pendientes" (HMAC) creada con éxito.');
  }

  /// Verifica si un folio ya fue escaneado en modo offline
  Future<bool> existeBoleto(String idBoleto) async {
    final db = await database;
    final resultado = await db.query(
      'viajes_pendientes',
      where: 'idBoleto = ?',
      whereArgs: [idBoleto],
      limit:
          1, // Solo nos interesa saber si existe, no necesitamos todos los datos
    );
    return resultado.isNotEmpty;
  }

  // OPERACIONES DEL VALIDADOR OFFLINE CON HMAC

  /// Guarda los datos del boleto firmado cuando no hay internet
  Future<int> guardarViajePendiente(
    String idPasajero,
    String idBoleto,
    String firma,
  ) async {
    final db = await database;

    final data = {
      'idPasajero': idPasajero,
      'idBoleto': idBoleto,
      'firma': firma,
      // Usar toUtc para evitar problemas de zonas horarias entre celular y servidor
      'fechaHoraEscaneo': DateTime.now().toUtc().toIso8601String(),
      'estatus': 'pendiente',
    };

    final id = await db.insert('viajes_pendientes', data);
    debugPrint('Viaje firmado guardado en bóveda local con ID $id');
    return id;
  }

  /// Recuperar todos los viajes atrapados en el teléfono para enviarlos
  Future<List<Map<String, dynamic>>> obtenerViajesPendientes() async {
    final db = await database;
    return await db.query(
      'viajes_pendientes',
      where: 'estatus = ?',
      whereArgs: ['pendiente'],
    );
  }

  /// Limpiar la bóveda una vez que el backend confirma que los recibió
  Future<void> borrarViajesSincronizados(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');

    await db.delete(
      'viajes_pendientes',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    debugPrint(
      'Bóveda limpiada. ${ids.length} viajes borrados tras sincronización.',
    );
  }
}
