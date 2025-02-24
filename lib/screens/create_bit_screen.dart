import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bit.dart';
import '../providers/bit_provider.dart';
import '../providers/settings_provider.dart';
import 'package:logging/logging.dart';

class CreateBitScreen extends StatefulWidget {
  const CreateBitScreen({Key? key});

  @override
  State<CreateBitScreen> createState() => _CreateBitScreenState();
}

class _CreateBitScreenState extends State<CreateBitScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _body = '';
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Logger _log = Logger('CreateBitScreen');

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
      createdAt: Timestamp.fromDate(DateTime.now()),
      updatedAt: Timestamp.fromDate(DateTime.now()), // Fix Timestamp error
    );
    try {
      _log.info(
          'Attempting to add bit: ${bit.toFirestore()}'); // Logging statement
      await Provider.of<BitProvider>(context, listen: false).addBit(bit);
      _log.info('Bit added successfully'); // Logging statement
    } catch (e) {
      // Handle error
      _log.severe('Error adding bit: $e'); // Logging statement
      if (_title.isEmpty && _body.isEmpty) {
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