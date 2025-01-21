import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/set_list_provider.dart';
import '../screens/create_set_list_screen.dart';
import '../screens/set_list_detail_screen.dart';
import 'package:intl/intl.dart';

class SetListsScreen extends StatefulWidget {
  const SetListsScreen({super.key});

  @override
  State<SetListsScreen> createState() => _SetListsScreenState();
}

class _SetListsScreenState extends State<SetListsScreen> {
  final _logger = Logger('SetListsScreen');

  Future<void> _renameSetList(BuildContext context, int setListId, String currentTitle) async {
    final newTitleController = TextEditingController(text: currentTitle);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Set List'),
        content: TextField(
          controller: newTitleController,
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<SetListProvider>(context, listen: false)
                  .renameSetList(setListId, newTitleController.text);
              Navigator.pop(context);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateSetList(BuildContext context, int setListId) async {
    try {
      await Provider.of<SetListProvider>(context, listen: false)
          .duplicateSetList(setListId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(content: Text('Set List duplicated!')),
        );
      }
    } catch (error) {
      _logger.severe('Error duplicating set list: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(content: Text('Error duplicating set list.')),
        );
      }
    }
  }

  Future<void> _deleteSetList(BuildContext ctx, int setListId) async {
    try {
      await Provider.of<SetListProvider>(ctx, listen: false)
          .deleteSetList(setListId);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(
          const SnackBar(content: Text('Set List deleted!')),
        );
      }
    } catch (error) {
      _logger.severe('Error deleting set list: $error');
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(
          const SnackBar(content: Text('Error deleting set list.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<SetListProvider>(context);

    return Scaffold(
        body: Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: settingsProvider.backgroundColor,
                title: Text('Set Lists', style: TextStyle(color: settingsProvider.textColor)),
                iconTheme: IconThemeData(color: settingsProvider.textColor),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateSetListScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
              body: Consumer<SetListProvider>(
                builder: (context, setListProvider, child) {
                  if (setListProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (setListProvider.setLists.isEmpty) {
                    return const Center(child: Text("No Set Lists Yet, Add one!"));
                  } else {
                    return ReorderableListView(
                      onReorder: (oldIndex, newIndex) {
                        setListProvider.reorderSetLists(oldIndex, newIndex);
                      },
                      children: [
                        for (int index = 0; index < setListProvider.setLists.length; index++)
                          ListTile(
                            key: ValueKey(setListProvider.setLists[index].id),
                            title: Text(setListProvider.setLists[index].title),
                            subtitle: Text(DateFormat('MM/dd/yyyy').format(setListProvider.setLists[index].date)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SetListDetailScreen(
                                    setList: setListProvider.setLists[index],
                                  ),
                                ),
                              );
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'Rename') {
                                  _renameSetList(context, index, setListProvider.setLists[index].title);
                                } else if (value == 'Duplicate') {
                                  _duplicateSetList(context, index);
                                } else if (value == 'Delete') {
                                  _deleteSetList(context, index);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'Rename',
                                  child: Text('Rename'),
                                ),
                                const PopupMenuItem(
                                  value: 'Duplicate',
                                  child: Text('Duplicate'),
                                ),
                                const PopupMenuItem(
                                  value: 'Delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            );
          },
        ),
    );
  }
}