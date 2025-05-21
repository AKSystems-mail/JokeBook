import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/bit.dart';
import '/providers/bit_provider.dart';
import '/providers/settings_provider.dart';

class EditBitScreen extends StatefulWidget {
  final Bit bit;
  const EditBitScreen({super.key, required this.bit});

  @override
  State<EditBitScreen> createState() => _EditBitScreenState();
}

class _EditBitScreenState extends State<EditBitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late String _title;
  late String _body;

  @override
  void initState() {
    super.initState();
    _title = widget.bit.title;
    _body = widget.bit.body;
    _titleController.text = _title;
    _bodyController.text = _body;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

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
    final updatedBit = Bit(
      id: widget.bit.id,
      title: _title,
      body: _body,
      userId: widget.bit.userId, // Include userId
      createdAt: widget.bit.createdAt,
      updatedAt: Timestamp.fromDate(DateTime.now()),
      order: widget.bit.order, // <<< ADDED: Keep original order // Fix Timestamp error
    );
    try {
      await Provider.of<BitProvider>(context, listen: false).updateBit(updatedBit);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bit. Error: $e')),
      );
    }
  }

  Future<void> _handlePop(bool didPop) async {
    if (!didPop) {
      _submit();
      await _saveBit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handlePop(false);
        return true;
      },
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) => Scaffold(
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor,
            title: const Text('Edit Bit'),
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
                    textCapitalization: TextCapitalization.sentences,
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
                      textCapitalization: TextCapitalization.sentences,
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