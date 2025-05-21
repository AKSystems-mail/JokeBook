// lib/models/bit.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'bit.g.dart';

@HiveType(typeId: 0)
class Bit extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String body;
  @HiveField(3)
  final String userId;
  @HiveField(4)
  final Timestamp createdAt;
  @HiveField(5)
  final Timestamp updatedAt;
  @HiveField(6) // New Hive field index
  int order;    // Add the order field

  Bit({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.order,
  });

 factory Bit.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bit(
      id: doc.id,
      title: data['title'] ?? '', // Add null checks for safety
      body: data['body'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(), // Provide default if null
      updatedAt: data['updatedAt'] ?? Timestamp.now(), // Provide default if null
      order: data['order'] ?? 0, // Read order, default to 0
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'userId': userId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'order': order, // Add order to Firestore map
    };
  }
}
