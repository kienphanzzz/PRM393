import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/event_model.dart';
import 'event_detail_screen.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _selectedDate = DateTime.now();
  final bool _isDark = ThemeController.isDark;

  void _refreshCalendar() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Calendar Schedule", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_box, color: AppColors.primary, size: 28),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EventDetailScreen(onEventUpdated: _refreshCalendar)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  primary: AppColors.primary,
                  onPrimary: AppColors.background,
                  surface: cardBg,
                  onSurface: textColor,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(minutes: 5)), // Chốt chặn vĩnh viễn không cho chọn ngày quá khứ
                lastDate: DateTime(2030),
                onDateChanged: (DateTime date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text("Events & Reminders", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: EventStorage.todayEvents.isEmpty
                ? const Center(child: Text("No upcoming schedule today", style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: EventStorage.todayEvents.length,
              itemBuilder: (context, index) {
                final event = EventStorage.todayEvents[index];
                IconData eventIcon = Icons.event;
                Color iconColor = Colors.green;

                if (event.type == 'Meeting') { eventIcon = Icons.groups; iconColor = Colors.indigo; }
                if (event.type == 'Fitness') { eventIcon = Icons.fitness_center; iconColor = Colors.orange; }
                if (event.type == 'Deadline') { eventIcon = Icons.notification_important; iconColor = Colors.redAccent; }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EventDetailScreen(event: event, onEventUpdated: _refreshCalendar)),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: iconColor.withOpacity(0.15),
                      child: Icon(eventIcon, color: iconColor, size: 18),
                    ),
                    title: Text(event.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(event.timeLocation, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() {
                          EventStorage.todayEvents.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}