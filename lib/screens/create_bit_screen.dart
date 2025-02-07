import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bit.dart';
import '../providers/bit_provider.dart';
import '../providers/settings_provider.dart';

class CreateBitScreen extends StatefulWidget {
  const CreateBitScreen({super.key});

  @override
  State<CreateBitScreen> createState() => _CreateBitScreenState();
}

class _CreateBitScreenState extends State<CreateBitScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _body = '';
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  void _submit() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();
  }

  Future<void> _saveBit() async {
    if (_title.isEmpty && _body.isEmpty) {
      return;
    }
    final bit = Bit(
      id: DateTime.now().toString(),
      title: _title,
      body: _body,
      userId: FirebaseAuth.instance.currentUser!.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now()
    );
    try {
      await Provider.of<BitProvider>(context, listen: false).addBit(bit, context);
    } catch (e) {
      // Handle error
      print(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create bit. Error: $e')),
        );
      }
    }
  }

  Future<void> _handlePop(bool didPop) async {
    if (!didPop) {
      _submit();
      await _saveBit();
    }
    if (context.mounted && didPop) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: _handlePop,
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) => Scaffold(
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
                    onSaved: (value) {
                      _title = value!;
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _bodyController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        hintText: 'Write your bit here...',
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter some text';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _body = value!;
                      },
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
