class Visitor {
  final String mobileNumber;
  final String name;
  final String email;
  final DateTime createdAt;

  Visitor({
    required this.mobileNumber,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'mobile_number': mobileNumber,
        'name': name,
        'email': email,
        'created_at': createdAt.toIso8601String(),
      };

  factory Visitor.fromJson(Map<String, dynamic> json) => Visitor(
        mobileNumber: json['mobile_number'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
}
