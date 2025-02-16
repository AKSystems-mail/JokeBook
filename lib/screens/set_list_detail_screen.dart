import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/set_list.dart';
import '../providers/set_list_provider.dart';
import '../models/bit.dart';
import '../providers/bit_provider.dart';
import '../screens/edit_bit_screen.dart';
import 'package:intl/intl.dart';
import '../providers/recordings_provider.dart';

class SetListDetailScreen extends StatefulWidget {
  final SetList setList;

  const SetListDetailScreen({super.key, required this.setList});

  @override
  State<SetListDetailScreen> createState() => _SetListDetailScreenState();
}

class _SetListDetailScreenState extends State<SetListDetailScreen> {
  late DateTime _selectedDate;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.setList.title);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.setList.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        widget.setList.date = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setListProvider = Provider.of<SetListProvider>(context);
    final bitProvider = Provider.of<BitProvider>(context);
    final recordingsProvider = Provider.of<RecordingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          onFieldSubmitted: (value) {
            widget.setList.title = value;
          },
          style:
              const TextStyle(color: Colors.black), // Set text color to white
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                if (recordingsProvider.isRecording()) {
                  recordingsProvider.stopRecording(context);
                } else {
                  recordingsProvider.startRecording(
                      widget.setList.title, widget.setList.id);
                }
              },
              child: Icon(
                recordingsProvider.isRecording()
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.red,
                size: 34.0,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                recordingsProvider.formattedRecordingDuration,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.setList.updatedAt = DateTime.now();
              setListProvider.updateSetList(widget.setList);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                    "Date: ${DateFormat('MM/dd/yy').format(widget.setList.date)}"),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Select Date'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Bits in this Set List:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.setList.bits.length,
                  itemBuilder: (context, index) {
                    final bitId = widget.setList.bits[index];
                    final bit = bitProvider.bits.firstWhere(
                      (b) => b.id == bitId,
                      orElse: () => Bit(
                        id: 'not-found',
                        title: 'Bit Not Found',
                        body: 'This bit has been deleted.',
                        userId: 'unknown', // Include userId
                        createdAt: Timestamp.fromDate(DateTime.now()),
                        updatedAt: Timestamp.fromDate(DateTime.now()),
                      ),
                    );

                    return ListTile(
                      title: Text(bit.title),
                      subtitle: Text(
                        bit.body.split('\n').take(2).join('\n') +
                            (bit.body.split('\n').length > 2 ? '...' : ''),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      minVerticalPadding: 10,
                      visualDensity: VisualDensity.compact,
                      dense: true,
                      onTap: bit.id != 'not-found'
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditBitScreen(bit: bit),
                                ),
                              );
                            }
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
