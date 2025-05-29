// lib/screens/create_set_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/set_list_provider.dart';
import '/providers/bit_provider.dart';
import '/models/bit.dart'; 
import 'package:intl/intl.dart';
import '/providers/settings_provider.dart';

class CreateSetListScreen extends StatefulWidget {
  const CreateSetListScreen({super.key});

  @override
  State<CreateSetListScreen> createState() => _CreateSetListScreenState();
}

class _CreateSetListScreenState extends State<CreateSetListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedBitIds = [];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get settingsProvider once for AppBar color, listen: false if not reacting to its changes in this build.
    // If settingsProvider can change and AppBar color needs to react, keep listen: true or use Consumer.
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        // Save the set list on back button press
        if (_formKey.currentState?.validate() ?? false) { // Use null-safe validate
          // Call SetListProvider's addSetList with the correct arguments
          // Your SetListProvider.addSetList expects:
          // Future<void> addSetList(String title, DateTime date, List<String> bitIds)
          try {
            await Provider.of<SetListProvider>(context, listen: false).addSetList(
              _titleController.text,
              _selectedDate,
              _selectedBitIds, // Pass the list of selected bit IDs
            );
          } catch (e) {
            // Handle or log error if saving on back press fails
            debugPrint("Error saving setlist onWillPop: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to auto-save setlist: $e')),
              );
            }
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: settingsProvider.backgroundColor,
          title: const Text('Create New Set List'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Added for better spacing
                  children: [
                    // Expanded to prevent overflow if date string is long
                    Expanded(child: Text("Date: ${DateFormat('MM/dd/yy').format(_selectedDate)}")),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align( // Align text to the left
                  alignment: Alignment.centerLeft,
                  child: Text("Select Bits:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8), // Added some space
                Expanded(
                  child: Consumer<BitProvider>(
                    builder: (context, bitProvider, child) {
                      if (bitProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (bitProvider.bits.isEmpty) {
                        return const Center(
                            child: Padding( // Added padding for better text display
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "No bits available. Go to the 'Bits' tab to create some first!",
                                textAlign: TextAlign.left,
                              ),
                            ));
                      }
                      return ListView.builder(
                        itemCount: bitProvider.bits.length,
                        itemBuilder: (context, index) {
                          final Bit bit = bitProvider.bits[index];
                          return CheckboxListTile(
                            title: Text(bit.title),
                            value: _selectedBitIds.contains(bit.id),
                            onChanged: (bool? newValue) {
                              setState(() {
                                if (newValue == true) { 
                                  if (!_selectedBitIds.contains(bit.id)) {
                                     _selectedBitIds.add(bit.id);
                                  }
                                } else {
                                  _selectedBitIds.remove(bit.id);
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}