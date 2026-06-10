import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isDark = ThemeController.isDark;
  bool _isYearView = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _refreshCalendar() {
    setState(() {});
  }

  String _getLunarDate(DateTime date) {
    return "Ngày ${(date.day % 29) + 1} tháng ${(date.month % 12) + 1} (Âm lịch)";
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    List<EventModel> filteredEvents = EventStorage.userEvents.where((e) {
      bool matchesSearch = e.title.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesDate = e.startTime.startsWith(DateFormat('yyyy-MM-dd').format(_selectedDate));
      return matchesSearch && matchesDate;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(textColor),
            _buildSearchAndToggle(cardBg, textColor),
            if (!_isYearView) _buildCalendarGrid(cardBg, textColor),
            if (_isYearView) _buildYearView(textColor),
            _buildEventHeader(textColor, filteredEvents.length),
            _buildEventList(filteredEvents, cardBg, textColor),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(onEventUpdated: _refreshCalendar))),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Lịch biểu", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(_getLunarDate(_selectedDate), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          IconButton(
            icon: Icon(_isYearView ? Icons.calendar_today : Icons.apps, color: AppColors.primary),
            onPressed: () => setState(() => _isYearView = !_isYearView),
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndToggle(Color cardBg, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: "Tìm kiếm sự kiện...",
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(Color cardBg, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, onPrimary: AppColors.background, surface: cardBg, onSurface: textColor),
        ),
        child: CalendarDatePicker(
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          onDateChanged: (date) => setState(() => _selectedDate = date),
        ),
      ),
    );
  }

  Widget _buildYearView(Color textColor) {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
        itemCount: 12,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => setState(() { _selectedDate = DateTime(_selectedDate.year, index + 1, 1); _isYearView = false; }),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
              child: Text(DateFormat('MMMM').format(DateTime(2025, index + 1)), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventHeader(Color textColor, int count) {
    if (_isYearView) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Sự kiện ngày ${DateFormat('dd/MM').format(_selectedDate)}", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          Text("$count sự kiện", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEventList(List<EventModel> events, Color cardBg, Color textColor) {
    if (_isYearView) return const SizedBox();
    return Expanded(
      child: events.isEmpty
          ? Center(child: Text("Không có sự kiện nào", style: TextStyle(color: AppColors.textMuted)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final e = events[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(event: e, onEventUpdated: _refreshCalendar))),
                    leading: Text(e.sticker, style: const TextStyle(fontSize: 24)),
                    title: Text(e.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("${e.startTime.split(' ')[1]} - ${e.location}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () async {
                        EventStorage.userEvents.remove(e);
                        await EventStorage.saveEvents();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
