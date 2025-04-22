// lib/providers/bit_provider.dart

import 'package:flutter/material.dart';
import '/models/bit.dart';
import '/services/firestore_service.dart';

class BitProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Bit> _bits = [];

  List<Bit> get bits => _bits;

  BitProvider() {
    _firestoreService.getBitsStream().listen((bits) {
      _bits = bits;
      notifyListeners();
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

  void reorderBits(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Bit bit = _bits.removeAt(oldIndex);
    _bits.insert(newIndex, bit);
    notifyListeners();
  }
}
