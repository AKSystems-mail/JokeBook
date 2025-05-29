// lib/providers/bit_provider.dart

import 'package:flutter/material.dart';
import '/models/bit.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For WriteBatch
import '/services/firestore_service.dart';

class BitProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Bit> _bits = [];
  bool _isLoading = true; // Added loading state

  List<Bit> get bits => _bits;
  bool get isLoading => _isLoading; // Added isLoading getter

  BitProvider() {
    _firestoreService.getBitsStream().listen((bitsFromStream) {
      _bits = bitsFromStream; // This list is now ordered by 'order' from Firestore
      if (_isLoading) { // Set isLoading to false after the first data load
        _isLoading = false;
      }
      notifyListeners();
    }, onError: (error) {
      // Handle error appropriately, e.g., set an error state
      // You might also want to set _isLoading to false on error
       if (_isLoading) {
         _isLoading = false;
         notifyListeners(); // Notify even on error if loading state changes
       }
    });
  }

  Future<void> addBit(Bit bit) async {
    await _firestoreService.addBit(bit);
    // The stream listener will handle adding the bit to the _bits list
    // notifyListeners(); // No need to notify here, stream will trigger it
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
    await _firestoreService.deleteBit(bitId);
    // The stream listener will handle removing the bit from the _bits list
    // _bits.removeWhere((bit) => bit.id == bitId);
    // notifyListeners(); // No need to notify here, stream will trigger it
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
