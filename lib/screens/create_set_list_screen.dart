import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/set_list.dart';
import '/providers/set_list_provider.dart';
import '/providers/bit_provider.dart';
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
    final bitProvider = Provider.of<BitProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        // Save the set list on back button press
        if (_formKey.currentState!.validate()) {
          final newSetList = SetList(
            id: DateTime.now().toString(),
            title: _titleController.text,
            date: _selectedDate,
            bits: _selectedBitIds,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          Provider.of<SetListProvider>(context, listen: false)
              .addSetList(newSetList);
        }
        return true; // Allow navigation
      },
      child: Scaffold(
        body: Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) => Scaffold(
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
                        TextCapitalization.sentences;
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    Row(
                      children: [
                        Text(
                            "Date: ${DateFormat('MM/dd/yy').format(_selectedDate)}"),
                        TextButton(
                          onPressed: () => _selectDate(context),
                          child: const Text('Select Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Select Bits:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: bitProvider.bits.isEmpty
                          ? const Center(
                              child:
                                  Text("No bits available, create a bit first"))
                          : ListView.builder(
                              itemCount: bitProvider.bits.length,
                              itemBuilder: (context, index) {
                                final bit = bitProvider.bits[index];
                                return CheckboxListTile(
                                  title: Text(bit.title),
                                  value: _selectedBitIds.contains(bit.id),
                                  onChanged: (bool? newValue) {
                                    setState(() {
                                      if (newValue!) {
                                        _selectedBitIds.add(bit.id);
                                      } else {
                                        _selectedBitIds.remove(bit.id);
                                      }
                                    });
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
        ),
      ),
    );
  }
}
