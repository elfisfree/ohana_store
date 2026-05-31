// lib/models/user_address.dart
class UserAddress {
  final String id;
  final String? name;
  final String city;
  final String street;
  final String house;
  final String? floor;
  final String? apartment;

  UserAddress({
    required this.id,
    this.name,
    required this.city,
    required this.street,
    required this.house,
    this.floor,
    this.apartment,
  });

  String get fullAddress {
    String base = "г. $city, ул. $street, д. $house";
    if (floor != null && floor!.isNotEmpty) {
      base += ", эт. $floor";
    }
    if (apartment != null && apartment!.isNotEmpty) {
      base += ", кв. $apartment";
    }
    return base;
  }

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'],
      name: json['name'],
      city: json['city'] ?? 'Казань',
      street: json['street'] ?? '',
      house: json['house'] ?? '',
      floor: json['floor'],
      apartment: json['apartment'],
    );
  }
}
