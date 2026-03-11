import 'package:flutter/material.dart';

import 'auth/auth.dart';
import 'store/grocery_store_state.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  final Future<GroceryStoreState> _storeFuture = GroceryStoreState.create(
    baseUrl: _apiBaseUrl,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: FutureBuilder<GroceryStoreState>(
        future: _storeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return const Scaffold(
              body: Center(child: Text('Failed to load store data.')),
            );
          }

          return AuthGate(store: snapshot.data!);
        },
      ),
    );
  }
}
