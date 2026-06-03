// lib/providers/bit_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for User type
import '/models/bit.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For WriteBatch
import '/services/firestore_service.dart';
import 'package:uuid/uuid.dart'; // Import the uuid package

class BitProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Bit> _bits = [];
  bool _isLoading = true; // Added loading state

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<Bit>>? _bitsSubscription;

  List<Bit> get bits => _bits;
  bool get isLoading => _isLoading; // Added isLoading getter

  BitProvider() {
    _authSubscription = _firestoreService.auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToBits();
      } else {
        _unsubscribeFromBits();
        _bits = [];
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void _subscribeToBits() {
    _bitsSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _bitsSubscription = _firestoreService.getBitsStream().listen((bitsFromStream) {
      _bits = bitsFromStream; // This list is now ordered by 'order' from Firestore
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
       _isLoading = false;
       notifyListeners(); // Notify even on error if loading state changes
    });
  }

  void _unsubscribeFromBits() {
    _bitsSubscription?.cancel();
    _bitsSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _bitsSubscription?.cancel();
    super.dispose();
  }

  Future<void> addBit(Bit bit) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      print("Cannot add bit: User not authenticated.");
      throw Exception('User not authenticated.');
    }

    WriteBatch batch = _firestoreService.db.batch();
    final userBitsRef = _firestoreService.db.collection('users').doc(user.uid).collection('bits');

    // 1. Shift order of all existing bits by +1
    for (final existingBit in _bits) {
      final docRef = userBitsRef.doc(existingBit.id);
      batch.update(docRef, {'order': existingBit.order + 1});
    }

    // 2. Add the new bit with order 0
    // We use the data from the passed-in bit, but enforce order = 0.
    final newBit = Bit(
      id: bit.id.isNotEmpty ? bit.id : const Uuid().v4(), // Use passed ID or generate new one
      title: bit.title,
      body: bit.body,
      userId: user.uid, // Ensure correct user ID
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      order: 0, // New items always get order 0
    );
    final newDocRef = userBitsRef.doc(newBit.id);
    batch.set(newDocRef, newBit.toFirestore());

    try {
      await batch.commit();
      print("Bit added successfully with order 0. New ID: ${newBit.id}");
      // The stream will automatically update the UI.
    } catch (e) {
      print("Failed to add bit with shifted order: $e");
      throw Exception('Failed to save new bit: $e');
    }
  }

  Future<void> updateBit(Bit bit) async {
    await _firestoreService.updateBit(bit);
    // The stream listener will handle updating the bit in the _bits list
    // final index = _bits.indexWhere((b) => b.id == bit.id);
    // if (index != -1) {
    //   _bits[index] = bit;
    //   notifyListeners(); // No need to notify here, stream will trigger it
    // }
  }

  Future<void> deleteBit(String bitId) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      print("Cannot delete bit: User not authenticated.");
      throw Exception('User not authenticated.');
    }

    final bitToRemove = _bits.firstWhere((b) => b.id == bitId, orElse: () => throw Exception("Bit not found locally for deletion"));
    final removedOrder = bitToRemove.order;

    WriteBatch batch = _firestoreService.db.batch();
    final userBitsRef = _firestoreService.db.collection('users').doc(user.uid).collection('bits');

    // 1. Delete the bit
    batch.delete(userBitsRef.doc(bitId));

    // 2. Decrement order of subsequent bits
    for (final bit in _bits) {
      if (bit.id != bitId && bit.order > removedOrder) {
        batch.update(userBitsRef.doc(bit.id), {'order': bit.order - 1});
      }
    }

    try {
      await batch.commit();
      print("Bit $bitId deleted and subsequent orders shifted.");
    } catch (e) {
      print("Failed to delete bit $bitId and shift orders: $e");
      throw Exception('Failed to delete bit: $e');
    }
  }

  // This is the critical method for reordering
  Future<void> reorderBits(int oldIndex, int newIndexFromListView) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      return;
    }

    // 1. Adjust newIndex (standard for ReorderableListView)
    int newActualIndex = newIndexFromListView;
    if (newActualIndex > oldIndex) {
      newActualIndex -= 1;
    }

    // Boundary checks
    if (oldIndex < 0 || oldIndex >= _bits.length || newActualIndex < 0 || newActualIndex >= _bits.length) {
      return;
    }

    // 2. Perform local reorder for immediate UI feedback
    final Bit item = _bits.removeAt(oldIndex);
    _bits.insert(newActualIndex, item);

    // 3. Update 'order' property for all bits in the local list
    //    and identify which ones actually changed order to minimize batch writes.
    List<Bit> bitsToUpdateInFirestore = [];
    for (int i = 0; i < _bits.length; i++) {
      // Check if the current order matches its new index OR if it's one of the moved items
      // to ensure the order field is always correct after a local move.
      if (_bits[i].order != i || _bits[i].id == item.id) {
        _bits[i].order = i; // Assign new sequential order
        // If your Bit model's updatedAt is mutable and should be updated on reorder:
        // _bits[i].updatedAt = Timestamp.now();
        bitsToUpdateInFirestore.add(_bits[i]);
      }
    }
    notifyListeners(); // Update UI with locally reordered list (orders are now 0, 1, 2...)


    // 4. Persist the new order to Firestore using a batch write
    //    Only write if there are actual changes to the 'order' field or updatedAt.
     if (bitsToUpdateInFirestore.isEmpty) {
         return; // No actual order values changed, skip batch
     }

    WriteBatch batch = _firestoreService.db.batch();
    for (final bitToUpdate in bitsToUpdateInFirestore) {
      DocumentReference bitRef = _firestoreService.db
          .collection('users')
          .doc(user.uid)
          .collection('bits')
          .doc(bitToUpdate.id);
      // Only include 'updatedAt' if it's part of your Bit model and should change on reorder
      batch.update(bitRef, {'order': bitToUpdate.order /*, 'updatedAt': bitToUpdate.updatedAt */});
    }

    try {
      await batch.commit();
      // The stream listener for getBitsStream will eventually reflect this authoritative state.
      // No explicit notifyListeners() needed after commit because the stream triggers it.
    } catch (e) {
      // Revert local changes or re-fetch to ensure consistency if batch commit fails.
      // Re-fetching is generally safer to get the authoritative state.
      // For simplicity, we'll rely on the stream to eventually correct,
      // but this could cause temporary UI flicker or incorrect order if the stream lags or fails.
      // A more robust error handling would involve actively reverting the local _bits list
      // or attempting a re-fetch immediately on error.
      // Example simple re-fetch on error:
      // _firestoreService.getBitsStream().first.then((correctedBits) {
      //   _bits = correctedBits;
      //   notifyListeners();
      // }).catchError((_) {
      //   // Handle re-fetch error
      // });

      // Consider setting an error state here as well
      throw e; // Propagate error
    }
  }
}
