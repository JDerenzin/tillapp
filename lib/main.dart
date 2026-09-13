import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  runApp(const Tillapp());
}

class Producto {
  final String nombre;
  final double precio;

  Producto({required this.nombre, required this.precio});

  // Convertir de JSON (al leer del caché o Supabase)
  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      nombre: json['nombre'] ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Convertir a JSON (para guardar en el caché)
  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'precio': precio};
  }
}

class Tillapp extends StatefulWidget {
  const Tillapp({super.key});

  @override
  State<Tillapp> createState() => _TillappState();
}

class _TillappState extends State<Tillapp> {
  List<Producto> _productos = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadFromCache(); // 1. Carga inmediata desde la caché
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString('cache_productos');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      setState(() {
        _productos = jsonList.map((item) => Producto.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveToCache(List<Producto> productos) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      productos.map((p) => p.toJson()).toList(),
    );
    await prefs.setString('cache_productos', jsonString);
  }

  Future<void> _syncWithSupabase() async {
    setState(() => _isSyncing = true);

    try {
      final response = await Supabase.instance.client
          .from('productos')
          .select('nombre, precio');

      final List<dynamic> data = response as List<dynamic>;
      final List<Producto> remoteProductos =
          data.map((item) => Producto.fromJson(item as Map<String, dynamic>)).toList();

      setState(() {
        _productos = remoteProductos;
      });

      await _saveToCache(remoteProductos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tillapp'),
          actions: [
            _isSyncing
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: _syncWithSupabase,
                    tooltip: 'Actualizar productos',
                  ),
          ],
        ),
        body: _productos.isEmpty
            ? const Center(child: Text('No hay productos guardados.'))
            : ListView.builder(
                itemCount: _productos.length,
                itemBuilder: (context, index) {
                  final producto = _productos[index];
                  return ListTile(
                    leading: const Icon(Icons.shopping_bag),
                    title: Text(producto.nombre),
                    subtitle: Text('S/ ${producto.precio.toStringAsFixed(2)}'),
                  );
                },
              ),
      ),
    );
  }
}
