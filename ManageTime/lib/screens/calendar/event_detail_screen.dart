import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel? event;
  final VoidCallback onEventUpdated;

  const EventDetailScreen({super.key, this.event, required this.onEventUpdated});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  String _selectedType = 'Meeting';
  int _reminderMinutes = 10;
  final bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _selectedType = widget.event!.type;
      final parts = widget.event!.timeLocation.split(' - ');
      if (parts.length >= 2) {
        _locationController.text = parts.sublist(1).join(' - ');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Vui lòng điền đủ thông tin')),
      );
      return;
    }

    final String formattedTime = _selectedTime.format(context);
    final String timeAndLoc = '$formattedTime - ${_locationController.text.trim()}';

    // Nghiệp vụ kiểm tra trùng khung giờ (Time-conflict Validation)
    bool isConflict = EventStorage.todayEvents.any((item) =>
    item.id != widget.event?.id &&
        item.timeLocation.split(' - ')[0] == formattedTime
    );

    if (isConflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Khung giờ này bạn đã có một lịch trình khác diễn ra!'),
        ),
      );
      return;
    }

    if (widget.event == null) {
      EventStorage.todayEvents.add(
        EventModel(
          id: DateTime.now().toString(),
          title: _titleController.text.trim(),
          timeLocation: timeAndLoc,
          type: _selectedType,
        ),
      );
    } else {
      widget.event!.title = _titleController.text.trim();
      widget.event!.timeLocation = timeAndLoc;
      widget.event!.type = _selectedType;
    }

    widget.onEventUpdated();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Color bg = _isDark ? AppColors.background : Colors.grey.shade100;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    Color textColor = _isDark ? Colors.white : Colors.black87;
    bool isEditMode = widget.event != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 10),
              Text(isEditMode ? 'Edit Event Schedule' : 'Create New Event', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text('Event Title', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'E.g., Họp tiến độ đồ án',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pick Time', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectTime(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_selectedTime.format(context), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'E.g., Hall Alpha',
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveEvent,
                  child: Text(isEditMode ? 'Update Event Schedule' : 'Set Schedule Reminder', style: const TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}