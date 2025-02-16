import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/set_list_provider.dart';
import '/providers/settings_provider.dart';
import 'set_list_detail_screen.dart';
import 'create_set_list_screen.dart';

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
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: setListProvider.setLists.length,
                  itemBuilder: (context, index) {
                    final setList = setListProvider.setLists[index];
                    return Card(
                      key: ValueKey(setList.id),
                      elevation: 2.0,
                      child: ListTile(
                        title: Text(
                          setList.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SetListDetailScreen(setList: setList),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
