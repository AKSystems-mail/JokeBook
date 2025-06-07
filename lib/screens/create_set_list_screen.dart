// lib/screens/create_set_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

import '/providers/set_list_provider.dart';
import '/providers/bit_provider.dart'; // Import BitProvider
import '/models/bit.dart';             // Import Bit model
import '/providers/settings_provider.dart'; // Assuming you use this for AppBar color

class CreateSetListScreen extends StatefulWidget {
  const CreateSetListScreen({super.key});

  @override
  State<CreateSetListScreen> createState() => _CreateSetListScreenState();
}

class _CreateSetListScreenState extends State<CreateSetListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedBitIds = []; // Keep this

  @override
  void initState() {
    super.initState();
    // Optional: If your BitProvider needs an explicit fetch and doesn't load bits via stream initially
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Provider.of<BitProvider>(context, listen: false).fetchBits(); // Or whatever your fetch method is
    // });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveSetList() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    // Optional: Check if at least one bit is selected
    // if (_selectedBitIds.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please select at least one bit.')),
    //   );
    //   return;
    // }

    try {
      await Provider.of<SetListProvider>(context, listen: false).addSetList(
        _titleController.text,
        _selectedDate,
        _selectedBitIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setlist saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save setlist: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
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
    // Access SettingsProvider for AppBar color
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        if (_formKey.currentState?.validate() ?? false) {
          // Using the same save logic as the save button for consistency on back press
          await Provider.of<SetListProvider>(context, listen: false).addSetList(
            _titleController.text,
            _selectedDate,
            _selectedBitIds,
          );
          // No need for ScaffoldMessenger here as we are popping immediately
        }
        return true; // Allow pop
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create New Set List'),
          backgroundColor: settingsProvider.backgroundColor, // From SettingsProvider
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSetList,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column( // Changed from ListView to Column for direct control with Expanded
              children: <Widget>[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Set List Title'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded( // Use Expanded to ensure Text takes available space
                      child: Text(
                          "Date: ${DateFormat('MM/dd/yy').format(_selectedDate)}"), // Using intl for formatting
                    ),
                    TextButton( // Changed to TextButton for better UI consistency
                      onPressed: _pickDate,
                      child: const Text("Select Date"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Select Bits:",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                // --- THIS IS THE CRUCIAL PART FOR DISPLAYING BITS ---
                Expanded(
                  child: Consumer<BitProvider>(
                    builder: (context, bitProvider, child) {
                      // Assuming BitProvider has an 'isLoading' property
                      // if (bitProvider.isLoading) {
                      //   return const Center(child: CircularProgressIndicator());
                      // }
                      if (bitProvider.bits.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "No bits available. Go to the 'Bits' tab to create some first!",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
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
                // --- END OF BIT SELECTION UI ---
              ],
            ),
          ),
        ),
      ),
    );
  }
}