import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/providers/settings_provider.dart';
import '/models/bit.dart';
import '/providers/bit_provider.dart';

class CreateBitScreen extends StatefulWidget {
  const CreateBitScreen({super.key});

  @override
  State<CreateBitScreen> createState() => _CreateBitScreenState();
}

class _CreateBitScreenState extends State<CreateBitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop) {
      if (_formKey.currentState!.validate()) {
        final newBit = Bit(
          id: DateTime.now().toString(),
          title: _titleController.text,
          body: _bodyController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await Provider.of<BitProvider>(context, listen: false).addBit(newBit);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: _handlePop,
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) => Scaffold( // Only ONE Scaffold
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor,
            title: const Text('New Bit'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: _bodyController,
                      textAlignVertical: TextAlignVertical.top,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'premise setup punch...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}