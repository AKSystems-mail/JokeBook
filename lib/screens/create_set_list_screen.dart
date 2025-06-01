import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/set_list_provider.dart';
// Import other necessary files like your BitProvider if used for selecting bits

class CreateSetListScreen extends StatefulWidget {
  const CreateSetListScreen({super.key});

  @override
  State<CreateSetListScreen> createState() => _CreateSetListScreenState();
}

class _CreateSetListScreenState extends State<CreateSetListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedBitIds = []; // Populate this list based on user selection

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveSetList() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await Provider.of<SetListProvider>(context, listen: false).addSetList(
          _titleController.text,
          _selectedDate,
          _selectedBitIds, // Use the bits selected on this screen
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setlist saved!')),
          );
          Navigator.of(context).pop(); // Go back after saving
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save setlist: $e')),
          );
        }
      }
    }
  }

  // Example method to pick date
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

  // Example: You would have UI elements to populate _selectedBitIds
  // For instance, a button that opens a dialog to select bits from BitProvider.
  // void _selectBits() async {
  //   final List<String>? result = await showDialog<List<String>>(
  //     context: context,
  //     builder: (context) => BitSelectionDialog(), // Your custom dialog
  //   );
  //   if (result != null) {
  //     setState(() {
  //       _selectedBitIds = result;
  //     });
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    // final bitProvider = Provider.of<BitProvider>(context); // If needed for bit selection UI

    return WillPopScope(
      onWillPop: () async {
        // This is called when the user presses the back button or an OS back gesture.
        // You might want to prompt the user if they want to save changes or discard.
        // For simplicity here, we'll attempt to save if valid.
        // If there's unsaved data, you might show a confirmation dialog.

        if (_formKey.currentState?.validate() ?? false) {
          // If the form is valid, you could auto-save, or prompt.
          // The snippet you provided had two save attempts. We only need one correct one.
          // Let's assume for onWillPop, if valid, we save.
          // If you want different behavior (e.g., prompt "Save changes?"), implement that here.

          // The problematic block was:
          // final newSetList = SetList(id: ..., title: ..., order: newOrder, ...);
          // await SetListProvider.addSetList(newSetList); // Incorrect static call & args
          // AND
          // await Provider.of<SetListProvider>(context, listen: false).addSetList(
          //   _titleController.text,
          //   _selectedDate,
          //   [], // This used an empty list for bits
          // );

          // We will use ONE correct call.
          // If onWillPop should save the selected bits:
          await Provider.of<SetListProvider>(context, listen: false).addSetList(
            _titleController.text,
            _selectedDate,
            _selectedBitIds, // Use the currently selected bits
          );
          // No need for another addSetList call.
        }
        return true; // Allow the pop to happen. Return false to prevent popping.
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create New Set List'),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSetList, // Call the save function
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView( // Use ListView for potentially long forms
              children: <Widget>[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Set List Title'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          "Date: ${_selectedDate.toLocal().toString().split(' ')[0]}"),
                    ),
                    ElevatedButton(
                      onPressed: _pickDate,
                      child: const Text("Select Date"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Placeholder for Bit Selection UI
                // You'll need to implement UI to select bits and populate _selectedBitIds
                // For example:
                // ElevatedButton(onPressed: _selectBits, child: Text("Select Bits")),
                // Text("Selected Bit IDs: ${_selectedBitIds.join(', ')}"),
                // ... your UI for selecting bits ...
              ],
            ),
          ),
        ),
      ),
    );
  }
}