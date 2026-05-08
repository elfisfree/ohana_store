class UserAddress {
  final String id;
  final String? name;
  final String addressLine;

  UserAddress({required this.id, this.name, required this.addressLine});

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'],
      name: json['name'],
      addressLine: json['address_line'],
    );
  }
}
