import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  // Patrón Singleton para mantener una sola instancia del archivero en toda la app
  static final LocalCacheService _instancia = LocalCacheService._interno();
  factory LocalCacheService() => _instancia;
  LocalCacheService._interno();

  // Llaves estáticas para los cajones del archivero
  static const String _keyDashboard = 'cache_dashboard';
  static const String _keyPerfil = 'cache_perfil';
  static const String _keyHistorial = 'cache_historial';
  static const String _keyUltimoViaje = 'cache_ultimo_viaje';

  // 1. CACHÉ DEL DASHBOARD (Billetera)
  Future<void> guardarDashboard(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDashboard, jsonEncode(data));
      debugPrint('Caché: Dashboard guardado.');
    } catch (e) {
      debugPrint('Error al guardar Dashboard en caché: $e');
    }
  }

  Future<Map<String, dynamic>?> obtenerDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString(_keyDashboard);
      if (dataString != null) return jsonDecode(dataString);
    } catch (e) {
      debugPrint('Error al leer Dashboard de caché: $e');
    }
    return null;
  }

  // 2. CACHÉ DEL PERFIL
  Future<void> guardarPerfil(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPerfil, jsonEncode(data));
      debugPrint('Caché: Perfil guardado.');
    } catch (e) {
      debugPrint('Error al guardar Perfil en caché: $e');
    }
  }

  Future<Map<String, dynamic>?> obtenerPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString(_keyPerfil);
      if (dataString != null) return jsonDecode(dataString);
    } catch (e) {
      debugPrint('Error al leer Perfil de caché: $e');
    }
    return null;
  }

  // 3. CACHÉ DEL HISTORIAL
  Future<void> guardarHistorial(List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHistorial, jsonEncode(data));
      debugPrint('Caché: Historial guardado.');
    } catch (e) {
      debugPrint('Error al guardar Historial en caché: $e');
    }
  }

  Future<List<dynamic>?> obtenerHistorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString(_keyHistorial);
      if (dataString != null) return jsonDecode(dataString);
    } catch (e) {
      debugPrint('Error al leer Historial de caché: $e');
    }
    return null;
  }

  // 4. CACHÉ DEL ÚLTIMO VIAJE (Mini-Historial)
  Future<void> guardarUltimoViaje(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUltimoViaje, jsonEncode(data));
      debugPrint('Caché: Último viaje guardado.');
    } catch (e) {
      debugPrint('Error al guardar Último Viaje en caché: $e');
    }
  }

  Future<Map<String, dynamic>?> obtenerUltimoViaje() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dataString = prefs.getString(_keyUltimoViaje);
      if (dataString != null) return jsonDecode(dataString);
    } catch (e) {
      debugPrint('❌ Error al leer Último Viaje de caché: $e');
    }
    return null;
  }

  // 5. LIMPIEZA TOTAL (Para el Cierre de Sesión)
  Future<void> limpiarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDashboard);
      await prefs.remove(_keyPerfil);
      await prefs.remove(_keyHistorial);
      await prefs.remove(_keyUltimoViaje);
      debugPrint('Caché: Bóveda local limpiada con éxito.');
    } catch (e) {
      debugPrint('Error al limpiar la caché: $e');
    }
  }
}
