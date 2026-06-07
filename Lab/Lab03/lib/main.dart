import 'dart:async';
import 'dart:convert';

class Product {
  final int id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';
}

class ProductRepository {
  final List<Product> _products = [
    Product(id: 1, name: 'Laptop', price: 1200.0),
    Product(id: 2, name: 'Phone', price: 800.0),
  ];

  final StreamController<Product> _controller = StreamController<Product>.broadcast();

  Future<List<Product>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _products;
  }

  Stream<Product> liveAdded() => _controller.stream;

  void addProduct(Product product) {
    _products.add(product);
    _controller.add(product);
  }

  void dispose() {
    _controller.close();
  }
}

class User {
  final String name;
  final String email;

  User({required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  @override
  String toString() => 'User(name: $name, email: $email)';
}

Future<List<User>> fetchUsers() async {
  await Future.delayed(const Duration(milliseconds: 500));
  String jsonMock = '[{"name": "Kien", "email": "kien@fpt.edu.vn"}, {"name": "An", "email": "an@fpt.edu.vn"}]';
  List<dynamic> decoded = jsonDecode(jsonMock) as List<dynamic>;
  return decoded.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
}

class Settings {
  final String theme;
  static final Map<String, Settings> _cache = <String, Settings>{};

  Settings._internal(this.theme);

  factory Settings(String theme) {
    return _cache.putIfAbsent(theme, () => Settings._internal(theme));
  }
}

void main() async {
  print('--- EXERCISE 1 ---');
  ProductRepository repo = ProductRepository();

  repo.liveAdded().listen((product) {
    print('Live product added: $product');
  });

  List<Product> allProducts = await repo.getAll();
  print('All products: $allProducts');

  repo.addProduct(Product(id: 3, name: 'Tablet', price: 400.0));
  await Future.delayed(const Duration(milliseconds: 100));


  print('\n--- EXERCISE 2 ---');
  List<User> users = await fetchUsers();
  print('Parsed users: $users');


  print('\n--- EXERCISE 3 ---');
  print('1. Main Start');

  Future(() {
    print('4. Event Queue Callback');
  });

  scheduleMicrotask(() {
    print('3. Microtask Queue Callback');
  });

  print('2. Main End');
  await Future.delayed(const Duration(milliseconds: 100));


  print('\n--- EXERCISE 4 ---');
  Stream<int> numStream = Stream<int>.fromIterable([1, 2, 3, 4, 5]);

  Stream<int> transformedStream = numStream
      .map((n) => n * n)
      .where((squared) => squared % 2 == 0);

  await for (int val in transformedStream) {
    print('Transformed value: $val');
  }


  print('\n--- EXERCISE 5 ---');
  Settings instanceA = Settings('dark');
  Settings instanceB = Settings('dark');

  print('Instance A hash: ${instanceA.hashCode}');
  print('Instance B hash: ${instanceB.hashCode}');
  print('Are instances identical? ${identical(instanceA, instanceB)}');

  repo.dispose();
}