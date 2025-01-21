import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

part 'set_list.g.dart';

final _logger = Logger('SetList');
@HiveType(typeId: 1)
class SetList {
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

  SetList({
    required this.id,
    required this.title,
    required this.date,
    required this.bits,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SetList.fromFirestore(DocumentSnapshot doc) {
    if (doc.data() == null) {
      _logger.info('Error: Document data is null');
      return SetList(
        id: doc.id,
        title: '',
        date: DateTime.now(),
        bits: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    if (!data['bits'].every((element) => element is String)) {
      _logger.info('Error: bits field contains non-string elements');
      throw ArgumentError('bits field must contain only strings');
    }
    var createdAtTimestamp = data['createdAt'] as Timestamp?;
    var updatedAtTimestamp = data['updatedAt'] as Timestamp?;
    
    return SetList(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bits: List<String>.from(data['bits'] ?? []),
      createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
      updatedAt: updatedAtTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': date,
      'bits': bits,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'bits': bits,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}