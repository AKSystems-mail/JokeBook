import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/set_list_provider.dart';
import '/providers/settings_provider.dart';
import '/models/set_list.dart'; // Add this import statement
import 'set_list_detail_screen.dart';
import 'create_set_list_screen.dart';
import 'package:intl/intl.dart'; // Add this import statement

class SetListsScreen extends StatelessWidget {
  const SetListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final setListProvider = Provider.of<SetListProvider>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor,
            title: const Text('Set Lists'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateSetListScreen(),
                        ),
                      );
                    },
                    child: const Text('New Set List'),
                  ),
                ),
              ),
            ],
          ),
          body: setListProvider.setLists.isEmpty
              ? const Center(child: Text("No set lists yet, create one!"))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: setListProvider.setLists.length,
                  itemBuilder: (context, index) {
                    final setList = setListProvider.setLists[index];
                    final formattedDate = DateFormat('MM/dd/yyyy').format(setList.date);
                    return Dismissible(
                      key: ValueKey(setList.id),
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) {
                        setListProvider.deleteSetList(setList.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${setList.title} deleted')),
                        );
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        key: ValueKey(setList.id),
                        elevation: 2.0,
                        child: ListTile(
                          title: Text(
                            setList.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(formattedDate),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SetListDetailScreen(setList: setList),
                              ),
                            );
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'Duplicate') {
                                _showDuplicateDialog(context, setListProvider, setList);
                              } else if (value == 'Rename') {
                                _showRenameDialog(context, setListProvider, setList);
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return {'Duplicate', 'Rename'}.map((String choice) {
                                return PopupMenuItem<String>(
                                  value: choice,
                                  child: Text(choice),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    setListProvider.reorderSetLists(oldIndex, newIndex);
                  },
                ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, SetListProvider setListProvider, SetList setList) {
    final TextEditingController _controller = TextEditingController(text: setList.title);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Set List'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Enter new name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setListProvider.renameSetList(setList.id, _controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  void _showDuplicateDialog(BuildContext context, SetListProvider setListProvider, SetList setList) {
    final TextEditingController _controller = TextEditingController(text: '${setList.title} (Copy)');
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duplicate Set List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Enter new name'),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  const Text('Date: '),
                  Text(DateFormat('MM/dd/yyyy').format(selectedDate)),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != selectedDate) {
                        selectedDate = picked;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setListProvider.duplicateSetList(setList, _controller.text, selectedDate);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}