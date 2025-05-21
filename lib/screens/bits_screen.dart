// lib/screens/bits_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/settings_provider.dart';
import '/providers/bit_provider.dart';
import 'edit_bit_screen.dart';
import 'create_bit_screen.dart';

class BitsScreen extends StatelessWidget {
  const BitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bitProvider = Provider.of<BitProvider>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor, // Tie AppBar background color to SettingsProvider
            title: const Text('Bits'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateBitScreen(),
                        ),
                      );
                    },
                    child: const Text('New Bit'),
                  ),
                ),
              ),
            ],
          ),
          body: bitProvider.bits.isEmpty
              ? const Center(child: Text("No new bits yet, Get to writing!"))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: bitProvider.bits.length,
                  itemBuilder: (context, index) {
                    final bit = bitProvider.bits[index];
                    return Dismissible(
                      key: ValueKey(bit.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirm Delete"),
                              content: const Text(
                                  "Are you sure you want to delete this bit?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        bitProvider.deleteBit(bit.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bit deleted')),
                        );
                      },
                      child: Card(
                        key: ValueKey(bit.id),
                        elevation: 5.0,
                        child: ListTile(
                          title: Text(
                            bit.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            bit.body.split('\n').take(2).join('\n'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditBitScreen(bit: bit),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    bitProvider.reorderBits(oldIndex, newIndex);
                  },
                  proxyDecorator:
                      (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                ),
        );
      },
    );
  }
}
