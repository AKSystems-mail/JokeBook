import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/models/bit.dart';
import '/providers/bit_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final updatedBit = Bit(
                  id: widget.bit.id,
                  title: _title,
                  body: _body,
                  createdAt: widget.bit.createdAt,
                  updatedAt: DateTime.now(),
                );
                Provider.of<BitProvider>(context, listen: false).updateBit(updatedBit);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                onChanged: (value) => setState(() => _title = value),
                validator: (value) {
                  if (value!.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const Divider(),
              Expanded(
                child: TextFormField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Start typing your bit here...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(height: 1.5),
                  onChanged: (value) => setState(() => _body = value),
                  validator: (value) {
                    if (value!.trim().isEmpty) {
                      return 'Please enter content';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}