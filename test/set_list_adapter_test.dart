import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jokebook/models/set_list.dart';

// Guards the Hive adapter: `order` was declared on the model but missing from
// the generated adapter, so every persisted set list came back unordered.
void main() {
  test('SetList keeps its order across a Hive round-trip', () async {
    Hive.init(Directory.systemTemp.createTempSync('jokebook_hive').path);
    Hive.registerAdapter(SetListAdapter());
    final box = await Hive.openBox<SetList>('setLists');
    final now = DateTime(2026, 1, 2);
    await box.put(
      'a',
      SetList(
        id: 'a',
        title: 'T',
        date: now,
        bits: ['b1'],
        createdAt: now,
        updatedAt: now,
        order: 7,
      ),
    );
    await box.close();

    final reopened = await Hive.openBox<SetList>('setLists');
    expect(reopened.get('a')!.order, 7);
    await reopened.close();
  });
}
