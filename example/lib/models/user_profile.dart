import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String name;
  final double heightCm;
  final double weightKg;
  final int age;
  final bool isMale;

  const UserProfile({
    required this.name,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.isMale,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    heightCm: (json['heightCm'] as num).toDouble(),
    weightKg: (json['weightKg'] as num).toDouble(),
    age: json['age'] as int,
    isMale: json['isMale'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'age': age,
    'isMale': isMale,
  };

  static const _key = 'user_profile';

  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null) return null;
    return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
