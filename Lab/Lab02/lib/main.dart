import 'dart:async';

class Car {
  String brand;

  Car(this.brand);
  Car.named(this.brand);

  void drive() {
    print('The $brand car is driving.');
  }
}

class ElectricCar extends Car {
  double batteryCapacity;

  ElectricCar(String brand, this.batteryCapacity) : super(brand);

  @override
  void drive() {
    print('The $brand electric car is driving silently. Battery: $batteryCapacity kWh.');
  }
}

void main() async {
  print('--- EXERCISE 1 ---');
  int age = 24;
  double height = 172.5;
  String name = 'Kien';
  bool isStudent = true;

  print('Name: $name, Age: $age');
  print('Height: ${height}cm, Is Student: $isStudent\n');

  print('--- EXERCISE 2 ---');
  List<int> numbers = [10, 20, 30];
  numbers.add(40);

  int sum = numbers[0] + numbers[1];
  bool isEqual = (numbers[2] == 30);
  print('List: $numbers, Sum: $sum, IsEqual: $isEqual');

  Set<String> tags = {'flutter', 'dart', 'flutter'};
  tags.add('mobile');
  print('Set elements: $tags');

  Map<String, String> config = {'env': 'production', 'version': '1.0.0'};
  print('Map version: ${config['version']}\n');

  print('--- EXERCISE 3 ---');
  int score = 85;
  if (score >= 90) {
    print('Grade: A');
  } else {
    print('Grade: B');
  }

  String day = 'Monday';
  switch (day) {
    case 'Monday':
      print('Start of work week.');
      break;
    default:
      print('Other day.');
  }

  List<String> fruits = ['Apple', 'Banana'];
  fruits.forEach((f) => print('Fruit: $f'));

  int arrowSquare(int x) => x * x;
  print('Square result: ${arrowSquare(5)}\n');

  print('--- EXERCISE 4 ---');
  Car regularCar = Car('Toyota');
  regularCar.drive();

  Car customCar = Car.named('Honda');
  customCar.drive();

  ElectricCar ev = ElectricCar('Tesla', 85.5);
  ev.drive();
  print('');

  print('--- EXERCISE 5 ---');
  print('Starting heavy task...');
  Future<String> fetchUserData() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'User Data Loaded';
  }
  String asyncResult = await fetchUserData();
  print('Async execution result: $asyncResult');

  String? nullableName;
  String displayName = nullableName ?? 'Guest';
  print('Null safety fallback name: $displayName');

  Stream<int> countStream() async* {
    for (int i = 1; i <= 3; i++) {
      yield i;
    }
  }
  await for (int val in countStream()) {
    print('Stream value received: $val');
  }
  print('--- LAB 2 FINISHED ---');
}