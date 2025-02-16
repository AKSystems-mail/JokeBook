import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/set_list_provider.dart';
import '../screens/set_list_detail_screen.dart';
import '../providers/settings_provider.dart';
import 'package:logging/logging.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  final _logger = Logger('CalendarScreen');
  List<dynamic> _setListsForDate = [];
  CalendarFormat _calendarFormat = CalendarFormat.month; // Add this line

  @override
  Widget build(BuildContext context) {
    final setListProvider = Provider.of<SetListProvider>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Calendar'),
          backgroundColor: settingsProvider
              .backgroundColor, // Update AppBar background color
        ),
        body: Container(
          color: settingsProvider.backgroundColor, // Apply background color
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2010, 10, 16),
                eventLoader: (day) {
                  return _getEventsForDay(day, setListProvider);
                },
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_focusedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!mounted) return; // Check if the widget is still mounted
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                  // Show Set Lists for the selected date
                  setState(() {
                    _setListsForDate =
                        setListProvider.setLists.where((setList) {
                      return isSameDay(setList.date, selectedDay);
                    }).toList();
                  });
                },
                calendarFormat: _calendarFormat, // Add this line
                onFormatChanged: (format) {
                  // Add this line
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
              ),
              const SizedBox(height: 8.0), // Add some spacing
              Expanded(
                // Wrap the ListView.builder with Expanded
                child: ListView.builder(
                  itemCount: _setListsForDate.length,
                  itemBuilder: (context, index) {
                    // Set List Tile
                    final setList = _setListsForDate[index];
                    return ListTile(
                      title: Text(setList.title),
                      subtitle:
                          Text(DateFormat('MM/dd/yyyy').format(setList.date)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                SetListDetailScreen(setList: setList),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List _getEventsForDay(DateTime day, SetListProvider setListProvider) {
    _logger.info('Checking events for day: $day');
    final events = setListProvider.setLists
        .where((setList) => isSameDay(setList.date, day))
        .toList();
    _logger.info('Events found: ${events.length}');
    return events.isNotEmpty ? ['Has Set List'] : [];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }
}
