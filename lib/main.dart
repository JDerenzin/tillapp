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
  final String precioFormateado;

  Producto({
    required this.nombre,
    required this.precio,
    required this.precioFormateado,
  });

  // Convertir de JSON (al leer del caché o Supabase)
  factory Producto.fromJson(Map<String, dynamic> json) {
    final precioNum = (json['precio'] as num?)?.toDouble() ?? 0.0;
    return Producto(
      nombre: json['nombre'] ?? '',
      precio: precioNum,
      precioFormateado: 'S/ ${precioNum.toStringAsFixed(2)}',
    );
  }

  // Convertir a JSON (para guardar en el caché)
  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'precio': precio};
  }
}

class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  // Cálculos limpios y memorizados por ítem
  double get subtotal => producto.precio * cantidad;
}

class Tillapp extends StatefulWidget {
  const Tillapp({super.key});

  @override
  State<Tillapp> createState() => _TillappState();
}

class _TillappState extends State<Tillapp> {
  List<Producto> _productos = [];
  bool _isSyncing = false;
  String _busqueda = '';
  List<Producto> _productosFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  final List<ItemCarrito> _carrito = [];

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString('cache_productos');
    //debugPrint('DATOS EN CACHÉ: $cachedData');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      final listaCargada = jsonList
          .map((item) => Producto.fromJson(item))
          .toList();
      setState(() {
        _productos = listaCargada;
        _productosFiltrados = listaCargada;
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
          .select('nombre, precio')
          .order('nombre', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final List<Producto> remoteProductos = data
          .map((item) => Producto.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _productos = remoteProductos;

        if (_busqueda.isEmpty) {
          _productosFiltrados = remoteProductos;
        } else {
          final query = _busqueda.toLowerCase().trim();
          _productosFiltrados = remoteProductos.where((producto) {
            return producto.nombre.toLowerCase().contains(query);
          }).toList();
        }
      });

      await _saveToCache(remoteProductos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _filtrarProductos(String texto) {
    final query = texto.toLowerCase().trim();

    setState(() {
      _busqueda = texto;
      if (query.isEmpty) {
        _productosFiltrados = _productos;
      } else {
        // .toLowerCase() a 'query' se hace UNA SOLA VEZ fuera del loop
        _productosFiltrados = _productos.where((producto) {
          return producto.nombre.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _agregarAlCarrito(Producto producto) {
    setState(() {
      final index = _carrito.indexWhere(
        (item) => item.producto.nombre == producto.nombre,
      );

      if (index != -1) {
        _carrito[index].cantidad++;
      } else {
        _carrito.add(ItemCarrito(producto: producto));
      }
    });
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Buscar producto...",
                  prefixIcon: Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filtrarProductos('');
                          },
                        )
                      : null,
                ),
                onChanged: _filtrarProductos,
              ),
            ),
            Expanded(
              child: _productos.isEmpty
                  ? const Center(child: Text('No hay productos guardados.'))
                  : _productosFiltrados.isEmpty
                  ? const Center(
                      child: Text('No se encontraron coincidencias.'),
                    )
                  : ListView.builder(
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        return Dismissible(
                          key: Key(producto.nombre),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            _agregarAlCarrito(producto);
                            return false; // Retorna false para que la fila no desaparezca del catálogo
                          },
                          background: Container(
                            color: Colors.green.shade600,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Row(
                              children: [
                                Icon(Icons.add_shopping_cart, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Agregar',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          child: ListTile(
                            title: Text(producto.nombre),
                            trailing: Text(producto.precioFormateado),
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),

            Expanded(
              child: _carrito.isEmpty
                  ? const Center(child: Text('El carrito está vacío.'))
                  : ListView.builder(
                      itemCount: _carrito.length,
                      itemBuilder: (context, index) {
                        final item = _carrito[index];
                        return ListTile(
                          title: Text(item.producto.nombre),
                          trailing: Text(item.producto.precioFormateado),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
