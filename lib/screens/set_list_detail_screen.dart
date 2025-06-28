// lib/screens/set_list_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
    _selectedDate = widget.setList.date;
    WakelockPlus.enable();
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
        widget.setList.date = picked;
        widget.setList.updatedAt = DateTime.now();
        Provider.of<SetListProvider>(context, listen: false)
            .updateSetList(widget.setList);
      });
    }
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context, String title) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Bit'),
          content: Text('Are you sure you want to delete "$title"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setListProvider = context.watch<SetListProvider>();
    final bitProvider = context.watch<BitProvider>();
    final recordingsProvider = context.watch<RecordingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          onFieldSubmitted: (value) {
            setState(() {
              widget.setList.title = value;
              widget.setList.updatedAt = DateTime.now();
              setListProvider.updateSetList(widget.setList);
            });
          },
          style: const TextStyle(color: Colors.black),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: RecordingButton(
              isRecording: recordingsProvider.isRecording(),
              onPressed: () {HapticFeedback.heavyImpact();
                final recorder = context.read<RecordingsProvider>();
                if (recorder.isRecording()) {
                  // Call stopRecording on the fresh instance
                  recorder.stopRecording(context);
                } else {
                  // Call startRecording on the fresh instance
                  recorder.startRecording(widget.setList.title, widget.setList.id);
                }
              },
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
                  fontSize: 24, // Increase the font size here
                ),
              ),
            ),
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
                Text("Date: ${DateFormat('MM/dd/yy').format(_selectedDate)}"),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text('Change Date'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Bits in this Set List:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Scrollbar(
                child: ReorderableListView(
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final String bitId =
                          widget.setList.bits.removeAt(oldIndex);
                      widget.setList.bits.insert(newIndex, bitId);
                      widget.setList.updatedAt = DateTime.now();
                      setListProvider.updateSetList(widget.setList);
                    });
                  },
                  children: [
                    for (int index = 0;
                        index < widget.setList.bits.length;
                        index++)
                      _buildBitTile(context, bitProvider,
                          widget.setList.bits[index], index),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBitTile(
      BuildContext context, BitProvider bitProvider, String bitId, int index) {
    final bit = bitProvider.bits.firstWhere(
      (b) => b.id == bitId,
      orElse: () => Bit(
        id: 'not-found',
        title: 'Bit Not Found',
        body: 'This bit has been deleted.',
        userId: 'unknown',
        createdAt: Timestamp.fromDate(DateTime.now()),
        updatedAt: Timestamp.fromDate(DateTime.now()),
        order: -1, 
      ),
    );

    return Dismissible(
      key: ValueKey(bitId),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: const Icon(Icons.swap_horiz, color: Colors.white, size: 40.0), // Increase the size here
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 40.0), // Increase the size here
      ),
       confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Replace/Add action
          // --- MODIFICATION: Pass bitId to the dialog ---
          _showReplaceBitDialog(context, bitProvider, index, bitId);
          return false; // Prevent dismissal, dialog handles action
        } else if (direction == DismissDirection.endToStart) {
          // Delete action
          // ... (delete confirmation logic remains the same) ...
           final confirmDelete = await _showDeleteConfirmationDialog(context, bit.title);
           if (confirmDelete) {
             setState(() {
               widget.setList.bits.removeAt(index);
               widget.setList.updatedAt = DateTime.now();
               Provider.of<SetListProvider>(context, listen: false)
                   .updateSetList(widget.setList);
             });
             // Return false because we manually updated state.
             // If provider update was guaranteed to rebuild immediately, could return true.
             // Returning false is safer here to avoid potential animation glitches.
             return false;
           }
           return false;
        }
        return false;
      },

      child: ListTile(
        title: Text(bit.title, style: const TextStyle(fontSize: 24.0)),
        subtitle: Text(
          bit.body.split('\n').take(2).join('\n') +
              (bit.body.split('\n').length > 2 ? '...' : ''),
          style: const TextStyle(fontSize: 20.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
      ),
    );
  }

  void _showReplaceBitDialog(BuildContext outerContext, BitProvider bitProvider, int originalBitIndexInSetlist, String swipedBitId) {
    // This list holds the state of selected bits for the dialog.
    // Initialize it with the bit that was swiped.
    List<String> selectedBitsForDialog = [swipedBitId];

    showDialog(
      context: outerContext, // Use outerContext to avoid confusion
      builder: (dialogContext) {
        return StatefulBuilder( // StatefulBuilder to manage the dialog's internal UI updates
          builder: (stfContext, stfSetState) { // stfSetState is for THIS StatefulBuilder
            return AlertDialog(
              // DialogTheme from main.dart will style the AlertDialog
              title: const Text('Select Bits'),
              content: SizedBox( // Constrain the size of the dialog content
                width: double.maxFinite,
                child: ListView.builder( // Use ListView.builder for scrollable content
                  shrinkWrap: true,
                  itemCount: bitProvider.bits.length,
                  itemBuilder: (context, itemIndex) {
                    final Bit currentBitInList = bitProvider.bits[itemIndex];
                    return CheckboxListTile(
                      title: Text(currentBitInList.title), // Text color from DialogTheme or ListTileTheme
                      value: selectedBitsForDialog.contains(currentBitInList.id),
                      activeColor: Theme.of(outerContext).colorScheme.primary, // Explicitly theme checkbox
                      checkColor: Theme.of(outerContext).colorScheme.onPrimary,
                      onChanged: (bool? newValue) {
                        stfSetState(() { // Use stfSetState to update dialog content
                          if (newValue == true) {
                            if (!selectedBitsForDialog.contains(currentBitInList.id)) {
                              selectedBitsForDialog.add(currentBitInList.id);
                            }
                          } else {
                            selectedBitsForDialog.remove(currentBitInList.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'), // TextButtonTheme will style this
                ),
                TextButton(
                  onPressed: () {
                    // This setState is for the main _SetListDetailScreenState
                    setState(() {
                      // Replace the bit at the original index with all selected bits
                      widget.setList.bits.removeAt(originalBitIndexInSetlist);
                      widget.setList.bits.insertAll(originalBitIndexInSetlist, selectedBitsForDialog);
                      widget.setList.updatedAt = DateTime.now();
                      Provider.of<SetListProvider>(outerContext, listen: false)
                          .updateSetList(widget.setList);
                    });
                    Navigator.of(dialogContext).pop(); // Close the dialog
                  },
                  child: const Text('OK'), // TextButtonTheme will style this
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class RecordingButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onPressed;

  const RecordingButton({
    Key? key,
    required this.isRecording,
    required this.onPressed,
  }) : super(key: key);

  @override
  _RecordingButtonState createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sizeAnimation = Tween<double>(begin: 50.0, end: 45.0).animate(_animationController);
    _colorAnimation = ColorTween(begin: Colors.grey, end: Colors.red).animate(_animationController);

    if (widget.isRecording) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: _sizeAnimation.value,
            height: _sizeAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorAnimation.value,
              border: Border.all(color: Colors.black, width: 2.0),
              boxShadow: widget.isRecording
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        spreadRadius: -2,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                widget.isRecording ? Icons.circle : Icons.circle_outlined,
                color: Colors.white,
                size: 24.0,
              ),
            ),
          );
        },
      ),
    );
  }
}