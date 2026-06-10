import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  final List<String> _stickers = ['📅', '🤝', '💪', '🚨', '🎓', '🎂', '✈️', '💻', '💡', '🔥'];

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
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
      _endTime = TimeOfDay.fromDateTime(DateFormat('yyyy-MM-dd HH:mm').parse(widget.event!.endTime));
    }
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  void _saveEvent() async {
    if (_titleController.text.trim().isEmpty) return;

    final startStr = DateFormat('yyyy-MM-dd').format(_startDate) + 
                    " ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}";
    final endStr = DateFormat('yyyy-MM-dd').format(_startDate) + 
                    " ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}";

    if (widget.event == null) {
      EventStorage.userEvents.add(EventModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        startTime: startStr,
        endTime: endStr,
        location: _locationController.text.trim(),
        type: _selectedType,
        sticker: _selectedSticker,
        isAllDay: _isAllDay,
        reminderMinutes: _reminderMinutes,
        repeatInterval: _repeatInterval,
      ));
    } else {
      widget.event!.title = _titleController.text.trim();
      widget.event!.description = _descController.text.trim();
      widget.event!.startTime = startStr;
      widget.event!.endTime = endStr;
      widget.event!.location = _locationController.text.trim();
      widget.event!.type = _selectedType;
      widget.event!.sticker = _selectedSticker;
      widget.event!.isAllDay = _isAllDay;
      widget.event!.reminderMinutes = _reminderMinutes;
      widget.event!.repeatInterval = _repeatInterval;
    }

    await EventStorage.saveEvents();
    widget.onEventUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text(widget.event == null ? 'Thêm sự kiện' : 'Chi tiết sự kiện', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                  items: _stickers.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 24)))).toList(),
                  onChanged: (val) => setState(() => _selectedSticker = val!),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(_titleController, 'Tên sự kiện...', cardBg, textColor)),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildLabel('Mô tả', textColor),
            _buildTextField(_descController, 'Chi tiết thêm...', cardBg, textColor, maxLines: 2),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Ngày', textColor),
                      GestureDetector(onTap: _selectDate, child: _buildDateBox(DateFormat('dd/MM/yyyy').format(_startDate), cardBg, textColor)),
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
                  Expanded(child: _buildTimePickerCol('Bắt đầu', _startTime, true, textColor, cardBg)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePickerCol('Kết thúc', _endTime, false, textColor, cardBg)),
                ],
              ),
            const SizedBox(height: 20),

            _buildLabel('Vị trí', textColor),
            _buildTextField(_locationController, 'Địa điểm hoặc Link meeting', cardBg, textColor, icon: Icons.location_on_outlined),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _buildDropdownCol('Nhắc trước', '$_reminderMinutes phút', [5, 10, 15, 30, 60], (v) => setState(() => _reminderMinutes = v as int), textColor, cardBg)),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdownCol('Lặp lại', _repeatInterval, ['None', 'Daily', 'Weekly', 'Monthly'], (v) => setState(() => _repeatInterval = v as String), textColor, cardBg)),
              ],
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _saveEvent,
                child: const Text('LƯU SỰ KIỆN', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(text, style: TextStyle(color: color.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)));
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, Color bg, Color txt, {int maxLines = 1, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: ctrl, maxLines: maxLines, style: TextStyle(color: txt),
        decoration: InputDecoration(
          hintText: hint, prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
          border: InputBorder.none, contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateBox(String date, Color bg, Color txt) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(date, style: TextStyle(color: txt, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAllDaySwitch(Color txt) {
    return Column(
      children: [
        Text('Cả ngày', style: TextStyle(color: txt.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
        Switch(value: _isAllDay, activeColor: AppColors.primary, onChanged: (v) => setState(() => _isAllDay = v)),
      ],
    );
  }

  Widget _buildTimePickerCol(String label, TimeOfDay time, bool isStart, Color txt, Color bg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, txt),
        GestureDetector(
          onTap: () => _selectTime(isStart),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Text(time.format(context), style: TextStyle(color: txt, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownCol(String label, String value, List items, ValueChanged onChanged, Color txt, Color bg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, txt),
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton(
              value: items.contains(int.tryParse(value.split(' ')[0])) ? int.tryParse(value.split(' ')[0]) : (items.contains(value) ? value : items[0]),
              dropdownColor: bg, icon: const Icon(Icons.arrow_drop_down),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i is int ? '$i phút' : i.toString(), style: TextStyle(color: txt)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}