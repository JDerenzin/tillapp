import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

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
