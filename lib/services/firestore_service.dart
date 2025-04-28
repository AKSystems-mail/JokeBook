// lib/services/firestore_service.dart  

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/models/bit.dart';
import '/models/set_list.dart';
import 'package:logging/logging.dart';
import '/models/recording.dart';

class FirestoreService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Logger _log = Logger('FirestoreService');

  Future<void> addBit(Bit bit) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding bit with ID ${bit.id} for user $userId');
    _log.info('Bit data: ${bit.toFirestore()}'); // Log toFirestore()

    return _db
        .collection('users')
        .doc(userId)
        .collection('bits')
        .doc(bit.id)
        .set(bit.toFirestore()) // Use toFirestore()
        .then((_) {
      _log.info('addBit function completed successfully');
    }).catchError((error) {
      _log.severe('Error adding bit to Firestore:', error);
      throw error;
    });
  }

  Future<void> updateBit(Bit bit) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _log.severe('User not authenticated!');
        throw Exception('User not authenticated!');
      }
      final userId = user.uid;
      _log.info('Updating bit with ID ${bit.id} for user $userId');
      await _db
          .collection('users')
          .doc(userId)
          .collection('bits')
          .doc(bit.id)
          .update(bit.toFirestore()); // Use toFirestore()
    } catch (e) {
      _log.severe('Error updating bit in Firestore:', e);
      rethrow;
    }
  }

  Future<void> deleteBit(String bitId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting bit with ID $bitId for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('bits')
          .doc(bitId)
          .delete();
    } catch (e) {
      _log.severe('Error deleting bit in Firestore:', e);
      rethrow;
    }
  }

  Stream<List<SetList>> getSetListsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      return Stream.value([]);
    }
    final userId = user.uid;
    _log.info('Getting all set lists for user $userId');
    return _db
        .collection('users')
        .doc(userId)
        .collection('setLists') // Lowercase 'l' - ensure consistency
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _log.fine('Received ${snapshot.docs.length} set lists from Firestore');
      // *** CORRECTED: Pass the DocumentSnapshot directly ***
      return snapshot.docs.map((doc) => SetList.fromFirestore(doc)).toList();
    });
  }

  Future<void> addSetList(SetList setList) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid; // Get userId for logging clarity

    final Map<String, dynamic> dataToAdd = {
      'title': setList.title,
      'date': Timestamp.fromDate(setList.date),
      'bits': setList.bits,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
       DocumentReference docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('setLists') // Lowercase 'l' - correct
          .add(dataToAdd);
       _log.info('Added set list with ID: ${docRef.id} for user $userId');
    } catch (e) {
       _log.severe('Error adding set list for user $userId: $e');
       // Rethrow or handle as appropriate
       rethrow;
    }
  }

  Future<void> updateSetList(SetList setList) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
     if (setList.id.isEmpty) {
       _log.warning('Attempted to update set list with empty ID.');
       throw Exception('SetList ID cannot be empty for update.');
     }
    final userId = user.uid; // Get userId for logging clarity

    final Map<String, dynamic> dataToUpdate = {
      'title': setList.title,
      'date': Timestamp.fromDate(setList.date),
      'bits': setList.bits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('setLists') // Lowercase 'l' - correct
          .doc(setList.id)
          .update(dataToUpdate);
      _log.info('Updated set list with ID: ${setList.id} for user $userId');
    } catch (e) {
       _log.severe('Error updating set list ${setList.id} for user $userId: $e');
       // Rethrow or handle as appropriate
       rethrow;
    }
  }

  Future<void> deleteSetList(String setListId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting set list with ID $setListId for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('setLists')
          .doc(setListId)
          .delete();
    } catch (e) {
      _log.severe('Error deleting set list in Firestore:', e);
      rethrow;
    }
  }

  Future<SetList> getSetList(String setListId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Getting set list with ID $setListId for user $userId');
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('setLists')
        .doc(setListId)
        .get();
    if (!doc.exists) {
      throw Exception('Set list not found');
    }
    return SetList.fromFirestore(doc);
  }

  Stream<List<Bit>> getBitsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      return Stream.empty();
    }
    final userId = user.uid;
    _log.info('Getting all bits for user $userId');
    return _db
        .collection('users')
        .doc(userId)
        .collection('bits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      _log.fine('Received ${snapshot.docs.length} bits from Firestore');
      return snapshot.docs.map((doc) => Bit.fromFirestore(doc)).toList();
    }).handleError((error) {
      _log.severe('Error getting bits stream from Firestore:', error);
      return Stream<List<Bit>>.empty();
    });
  }

  Future<List<Recording>> getRecordings() async {
    if (_auth.currentUser == null) {
      _log.severe('User not authenticated!');
      return [];
    }
    final userId = _auth.currentUser!.uid;
    _log.info('Getting all recordings for user $userId');
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Recording.fromFirestore(doc)).toList();
  }

  Future<void> addRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Adding recording with ID ${recording.id} for user $userId');
    await _db
        .collection('users')
        .doc(userId)
        .collection('recordings')
        .doc(recording.id)
        .set(recording.toFirestore()) // Use toFirestore()
        .then((_) {
      _log.info('addRecording function completed successfully');
    }).catchError((error) {
      _log.severe('Error adding recording to Firestore:', error);
      throw error;
    });
  }

  Future<void> deleteRecording(Recording recording) async {
    final user = _auth.currentUser;
    if (user == null) {
      _log.severe('User not authenticated!');
      throw Exception('User not authenticated!');
    }
    final userId = user.uid;
    _log.info('Deleting recording with ID ${recording.id} for user $userId');
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('recordings')
          .doc(recording.id)
          .delete();
    } catch (e) {
      _log.severe('Error deleting recording in Firestore:', e);
    }
  }
}