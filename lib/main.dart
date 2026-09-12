import 'package:flutter/material.dart';

void main() {
  runApp(const Tillapp());
}

class Tillapp extends StatefulWidget {
  const Tillapp({super.key});

  @override
  State<Tillapp> createState() => _TillappState();
}

class _TillappState extends State<Tillapp> {
String _mensaje = 'Bienvenido a Tillapp';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Tillapp')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_mensaje),
              const SizedBox(height: 20),
              const Text('Registra tus ventas fácilmente'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _mensaje = '¡Venta iniciada con éxito!';
                  });
                },
                child: const Text('Iniciar Venta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
