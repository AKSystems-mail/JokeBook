// lib/models/set_list.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

part 'set_list.g.dart';

final _logger = Logger('SetList');

@HiveType(typeId: 1)
class SetList extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime date;

  @HiveField(3)
  List<String> bits;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6) // Assign a unique HiveField typeId
  int? order; // Make it nullable

  SetList({
    required this.id,
    required this.title,
    required this.date,
    required this.bits,
    required this.createdAt,
    required this.updatedAt,
    this.order, // Include in constructor
  });

  // --- ADD THE COPYWITH METHOD HERE ---
  SetList copyWith({
    String? id,
    String? title,
    DateTime? date,
    List<String>? bits,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
    bool setOrderToNull = false, // Helper to explicitly set order to null if needed
  }) {
    return SetList(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      bits: bits ?? List<String>.from(this.bits), // Ensure bits are copied correctly
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: setOrderToNull ? null : (order ?? this.order),
    );
  }
  // --- END OF COPYWITH METHOD ---


  factory SetList.fromFirestore(DocumentSnapshot doc) {
    if (doc.data() == null) {
      _logger.warning('Warning: Document data is null for doc ID: ${doc.id}. Returning default SetList.');
      return SetList(
        id: doc.id,
        title: 'Error: Missing Data',
        date: DateTime.now(),
        bits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        order: null, // Handle nullable field
      );
    }
    
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;

    // Robust check for bits
    List<String> parsedBits = [];
    if (data['bits'] != null && data['bits'] is List) {
      try {
        parsedBits = List<String>.from((data['bits'] as List).map((item) => item.toString()));
      } catch (e) {
        _logger.warning('Warning: Error parsing bits field for doc ID: ${doc.id}. Bits: ${data['bits']}. Error: $e. Using empty list for bits.');
        parsedBits = [];
      }
    } else if (data['bits'] != null) {
        _logger.warning('Warning: bits field is not a List for doc ID: ${doc.id}. Bits: ${data['bits']}. Using empty list for bits.');
        parsedBits = [];
    }


    return SetList(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bits: parsedBits,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: data['order'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      // 'id': id, // Usually not stored in the document data if the document ID is the setlist ID
      'title': title,
      'date': Timestamp.fromDate(date),
      'bits': bits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'order': order,
    };
  }
}