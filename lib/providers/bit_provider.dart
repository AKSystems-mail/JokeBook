// lib/providers/bit_provider.dart

import 'package:flutter/material.dart';
import '/models/bit.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For WriteBatch
import '/services/firestore_service.dart';

class BitProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Bit> _bits = [];

  List<Bit> get bits => _bits;

  BitProvider() {
    _firestoreService.getBitsStream().listen((bitsFromStream) {
      _bits = bitsFromStream; // This list is now ordered by 'order' from Firestore
      notifyListeners();
    }, onError: (error) {
      print("Error in BitProvider stream listener: $error");
      // Handle error appropriately, e.g., set an error state
    });
  }

  Future<void> addBit(Bit bit) async {
    await _firestoreService.addBit(bit);
    notifyListeners();
  }

  Future<void> updateBit(Bit bit) async {
    await _firestoreService.updateBit(bit);
    final index = _bits.indexWhere((b) => b.id == bit.id);
    if (index != -1) {
      _bits[index] = bit;
      notifyListeners();
    }
  }

  Future<void> deleteBit(String bitId) async {
    await _firestoreService.deleteBit(bitId);
    _bits.removeWhere((bit) => bit.id == bitId);
    notifyListeners();
  }

  // This is the critical method for reordering
  Future<void> reorderBits(int oldIndex, int newIndexFromListView) async {
    final user = _firestoreService.auth.currentUser;
    if (user == null) {
      print("Cannot reorder bits: User not authenticated.");
      return;
    }

    // 1. Adjust newIndex (standard for ReorderableListView)
    int newActualIndex = newIndexFromListView;
    if (newActualIndex > oldIndex) {
      newActualIndex -= 1;
    }

    // Boundary checks
    if (oldIndex < 0 || oldIndex >= _bits.length || newActualIndex < 0 || newActualIndex >= _bits.length) {
      print("Invalid reorder indices: old=$oldIndex, new (target)=$newActualIndex. List length: ${_bits.length}");
      return;
    }

    // 2. Perform local reorder for immediate UI feedback
    final Bit item = _bits.removeAt(oldIndex);
    _bits.insert(newActualIndex, item);

    // 3. Update 'order' property for all bits in the local list
    //    and identify which ones actually changed order to minimize batch writes.
    List<Bit> bitsToUpdateInFirestore = [];
    for (int i = 0; i < _bits.length; i++) {
      if (_bits[i].order != i) { // Check if the current order matches its new index
        _bits[i].order = i; // Assign new sequential order
        // If your Bit model's updatedAt is mutable and should be updated on reorder:
        // _bits[i].updatedAt = Timestamp.now();
        bitsToUpdateInFirestore.add(_bits[i]);
      }
    }
    notifyListeners(); // Update UI with locally reordered list (orders are now 0, 1, 2...)

    // 4. Persist the new order to Firestore using a batch write
    if (bitsToUpdateInFirestore.isEmpty) {
        print("No order change needed for Firestore batch update.");
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
      print("Batch: Update bit ${bitToUpdate.id} to order ${bitToUpdate.order}");
    }

    try {
      await batch.commit();
      print("Successfully persisted reordered bits to Firestore for ${bitsToUpdateInFirestore.length} items.");
      // The stream listener for getBitsStream will eventually reflect this authoritative state.
    } catch (e) {
      print("Failed to persist bit order to Firestore: $e");
      // Revert local changes or re-fetch to ensure consistency.
      // For simplicity, we'll rely on the stream to correct, but this could cause temporary UI flicker.
      // A more robust error handling would involve re-fetching or reverting the local _bits list.
      // For now, the stream will eventually bring the correct state.
      // Consider re-fetching if an error occurs to ensure UI consistency:
      // _firestoreService.getBitsStream().first.then((correctedBits) {
      //   _bits = correctedBits;
      //   notifyListeners();
      // });
      throw e; // Propagate error
    }
  }
}
