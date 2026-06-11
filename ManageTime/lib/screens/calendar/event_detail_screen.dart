import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/event_model.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel? event;
  final VoidCallback onEventUpdated;

  // Thêm optional initialDate để sau này Calendar truyền ngày đang chọn vào được
  final DateTime? initialDate;

  const EventDetailScreen({
    super.key,
    this.event,
    this.initialDate,
    required this.onEventUpdated,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();

  String _selectedType = 'Meeting';
  String _selectedSticker = '📅';
  bool _isAllDay = false;
  int _reminderMinutes = 10;
  String _repeatInterval = 'None';

  bool _isDark = ThemeController.isDark;

  final List<String> _stickers = [
    '📅',
    '🤝',
    '💪',
    '🚨',
    '🎓',
    '🎂',
    '✈️',
    '💻',
    '💡',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();

    ThemeController.themeNotifier.addListener(_updateTheme);

    final now = DateTime.now();

    // Mặc định khi thêm mới: ngày hiện tại hoặc ngày Calendar truyền sang
    _startDate = widget.initialDate ?? now;

    _startTime = TimeOfDay(
      hour: now.hour,
      minute: now.minute,
    );

    final defaultEnd = now.add(const Duration(hours: 1));
    _endTime = TimeOfDay(
      hour: defaultEnd.hour,
      minute: defaultEnd.minute,
    );

    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descController.text = widget.event!.description;
      _locationController.text = widget.event!.location;

      _selectedType = widget.event!.type;
      _selectedSticker = widget.event!.sticker;
      _isAllDay = widget.event!.isAllDay;
      _reminderMinutes = widget.event!.reminderMinutes;
      _repeatInterval = widget.event!.repeatInterval;

      _startDate = DateFormat('yyyy-MM-dd HH:mm').parse(widget.event!.startTime);
      _startTime = TimeOfDay.fromDateTime(_startDate);

      final parsedEnd =
      DateFormat('yyyy-MM-dd HH:mm').parse(widget.event!.endTime);
      _endTime = TimeOfDay.fromDateTime(parsedEnd);
    }
  }

  void _updateTheme() {
    if (mounted) {
      setState(() {
        _isDark = ThemeController.isDark;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();

    ThemeController.themeNotifier.removeListener(_updateTheme);

    super.dispose();
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectDate() async {
    final today = _dateOnly(DateTime.now());

    DateTime initial = _dateOnly(_startDate);

    // Nếu ngày hiện tại trong form đang là quá khứ thì date picker sẽ nhảy về hôm nay
    if (initial.isBefore(today)) {
      initial = today;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(2030),
      helpText: 'Chọn ngày sự kiện',
      cancelText: 'Hủy',
      confirmText: 'OK',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc',
      cancelText: 'Hủy',
      confirmText: 'OK',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;

          final startDateTime = _combineDateAndTime(_startDate, _startTime);
          final endDateTime = _combineDateAndTime(_startDate, _endTime);

          // Nếu giờ kết thúc <= giờ bắt đầu thì tự đẩy giờ kết thúc thêm 1 tiếng
          if (!endDateTime.isAfter(startDateTime)) {
            final newEnd = startDateTime.add(const Duration(hours: 1));
            _endTime = TimeOfDay(hour: newEnd.hour, minute: newEnd.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Vui lòng nhập tên sự kiện');
      return;
    }

    final today = _dateOnly(DateTime.now());
    final selectedDay = _dateOnly(_startDate);

    if (selectedDay.isBefore(today)) {
      _showMessage('Không thể tạo sự kiện trong quá khứ');
      return;
    }

    DateTime startDateTime;
    DateTime endDateTime;

    if (_isAllDay) {
      startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        0,
        0,
      );

      endDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        23,
        59,
      );
    } else {
      startDateTime = _combineDateAndTime(_startDate, _startTime);
      endDateTime = _combineDateAndTime(_startDate, _endTime);

      final now = DateTime.now();

      if (startDateTime.isBefore(now)) {
        _showMessage('Giờ bắt đầu không được nằm trong quá khứ');
        return;
      }

      if (!endDateTime.isAfter(startDateTime)) {
        _showMessage('Giờ kết thúc phải sau giờ bắt đầu');
        return;
      }
    }

    final startStr = DateFormat('yyyy-MM-dd HH:mm').format(startDateTime);
    final endStr = DateFormat('yyyy-MM-dd HH:mm').format(endDateTime);

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    if (widget.event == null) {
      EventStorage.userEvents.add(
        EventModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: _descController.text.trim(),
          startTime: startStr,
          endTime: endStr,
          location: _locationController.text.trim(),
          type: _selectedType,
          sticker: _selectedSticker,
          isAllDay: _isAllDay,
          reminderMinutes: _reminderMinutes,
          repeatInterval: _repeatInterval,
          userEmail: email,
        ),
      );
    } else {
      widget.event!.title = title;
      widget.event!.description = _descController.text.trim();
      widget.event!.startTime = startStr;
      widget.event!.endTime = endStr;
      widget.event!.location = _locationController.text.trim();
      widget.event!.type = _selectedType;
      widget.event!.sticker = _selectedSticker;
      widget.event!.isAllDay = _isAllDay;
      widget.event!.reminderMinutes = _reminderMinutes;
      widget.event!.repeatInterval = _repeatInterval;
      widget.event!.userEmail = email;
    }

    await EventStorage.saveEvents();

    widget.onEventUpdated();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.event == null ? 'Thêm sự kiện' : 'Chi tiết sự kiện',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Tiêu đề & Sticker', textColor),
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedSticker,
                  dropdownColor: cardBg,
                  underline: Container(),
                  items: _stickers.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 24),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;

                    setState(() {
                      _selectedSticker = val;
                    });
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    _titleController,
                    'Tên sự kiện...',
                    cardBg,
                    textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabel('Mô tả', textColor),
            _buildTextField(
              _descController,
              'Chi tiết thêm...',
              cardBg,
              textColor,
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Ngày', textColor),
                      GestureDetector(
                        onTap: _selectDate,
                        child: _buildDateBox(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          cardBg,
                          textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildAllDaySwitch(textColor),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isAllDay)
              Row(
                children: [
                  Expanded(
                    child: _buildTimePickerCol(
                      'Bắt đầu',
                      _startTime,
                      true,
                      textColor,
                      cardBg,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePickerCol(
                      'Kết thúc',
                      _endTime,
                      false,
                      textColor,
                      cardBg,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            _buildLabel('Vị trí', textColor),
            _buildTextField(
              _locationController,
              'Địa điểm hoặc Link meeting',
              cardBg,
              textColor,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownCol(
                    'Nhắc trước',
                    _reminderMinutes,
                    [5, 10, 15, 30, 60],
                        (v) {
                      setState(() {
                        _reminderMinutes = v as int;
                      });
                    },
                    textColor,
                    cardBg,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownCol(
                    'Lặp lại',
                    _repeatInterval,
                    ['None', 'Daily', 'Weekly', 'Monthly'],
                        (v) {
                      setState(() {
                        _repeatInterval = v as String;
                      });
                    },
                    textColor,
                    cardBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveEvent,
                child: const Text(
                  'LƯU SỰ KIỆN',
                  style: TextStyle(
                    color: AppColors.background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl,
      String hint,
      Color bg,
      Color txt, {
        int maxLines = 1,
        IconData? icon,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: txt),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: icon != null
              ? Icon(
            icon,
            color: AppColors.textMuted,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateBox(String date, Color bg, Color txt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            date,
            style: TextStyle(
              color: txt,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDaySwitch(Color txt) {
    return Column(
      children: [
        Text(
          'Cả ngày',
          style: TextStyle(
            color: txt.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Switch(
          value: _isAllDay,
          activeColor: AppColors.primary,
          onChanged: (v) {
            setState(() {
              _isAllDay = v;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTimePickerCol(
      String label,
      TimeOfDay time,
      bool isStart,
      Color txt,
      Color bg,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, txt),
        GestureDetector(
          onTap: () => _selectTime(isStart),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              time.format(context),
              style: TextStyle(
                color: txt,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownCol(
      String label,
      dynamic value,
      List items,
      ValueChanged onChanged,
      Color txt,
      Color bg,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, txt),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton(
              value: value,
              dropdownColor: bg,
              icon: const Icon(Icons.arrow_drop_down),
              items: items.map((i) {
                return DropdownMenuItem(
                  value: i,
                  child: Text(
                    i is int ? '$i phút' : i.toString(),
                    style: TextStyle(color: txt),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}