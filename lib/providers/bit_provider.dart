import 'package:flutter/material.dart';
import '/models/bit.dart';
import 'package:provider/provider.dart';
import 'set_list_provider.dart';
import '/services/firestore_service.dart';

class BitProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<Bit> _bits = []; // Initialize as an empty list of Bit
  List<Bit> get bits => _bits;

  BitProvider() {
    _firestoreService.getBits().listen((bits) {
      _bits = bits.reversed.toList(); // Reverse the list
      notifyListeners();
    });
  }

  Future<void> addBit(Bit bit) async {
    try {
      await _firestoreService.addBit(bit);
    } catch (e) {
      // Handle error appropriately, e.g., show a snackbar or log
      rethrow; // Re-throw to allow calling code to handle it
    }
  }

  Future<void> updateBit(Bit bit) async {
    try {
      await _firestoreService.updateBit(bit); // Call Firestore service update method
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
    // Optimistically update the UI to avoid waiting for Firestore response
    final index = _bits.indexWhere((b) => b.id == bit.id);
    if (index != -1) {
      _bits[index] = bit;
      notifyListeners();
    }
  }

  void reorderBits(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Bit item = _bits.removeAt(oldIndex);
    _bits.insert(newIndex, item);
    notifyListeners();
  }

  Future<void> deleteBit(String id, BuildContext context) async {
    try {
      final index = _bits.indexWhere((bit) => bit.id == id);
      if (index != -1) {
        _bits.removeWhere((bit) => bit.id == id);
        await Provider.of<SetListProvider>(context, listen: false).removeBitFromSetLists(id);
      }
      await _firestoreService.deleteBit(id);
      notifyListeners();
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }
}