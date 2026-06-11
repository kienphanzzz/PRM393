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
    if (mounted) {
      setState(() {
        _isDark = ThemeController.isDark;
      });
    }
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

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasEventOnDate(DateTime date) {
    final String dateStr = DateFormat('yyyy-MM-dd').format(date);

    return EventStorage.userEvents.any((event) {
      return event.startTime.startsWith(dateStr);
    });
  }

  bool _isPastDay(DateTime date) {
    final today = _dateOnly(DateTime.now());
    return _dateOnly(date).isBefore(today);
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month - 1,
        1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        1,
      );
    });
  }

  void _openAddEventScreen() {
    final today = _dateOnly(DateTime.now());

    final DateTime initialDate = _dateOnly(_selectedDate).isBefore(today)
        ? today
        : _selectedDate;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          initialDate: initialDate,
          onEventUpdated: _refreshCalendar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    final List<EventModel> filteredEvents = EventStorage.userEvents.where((e) {
      final bool matchesSearch =
      e.title.toLowerCase().contains(_searchQuery.toLowerCase());

      final bool matchesDate =
      e.startTime.startsWith(DateFormat('yyyy-MM-dd').format(_selectedDate));

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
        onPressed: _openAddEventScreen,
        backgroundColor: AppColors.primary,
        child: const Icon(
          Icons.add,
          color: AppColors.background,
        ),
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
              Text(
                "Lịch biểu",
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getLunarDate(_selectedDate),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _isYearView ? Icons.calendar_today : Icons.apps,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                _isYearView = !_isYearView;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndToggle(Color cardBg, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          onChanged: (v) {
            setState(() {
              _searchQuery = v;
            });
          },
          decoration: InputDecoration(
            hintText: "Tìm kiếm sự kiện...",
            hintStyle: TextStyle(
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            border: InputBorder.none,
            icon: const Icon(
              Icons.search,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(Color cardBg, Color textColor) {
    final DateTime firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );

    final int daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;

    // DateTime.weekday: Monday = 1, Sunday = 7
    // UI đang dùng S M T W T F S nên Sunday là cột 0
    final int startWeekday = firstDayOfMonth.weekday % 7;

    final int totalCells = startWeekday + daysInMonth;
    final int rowCount = (totalCells / 7).ceil();
    final int itemCount = rowCount * 7;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<int>(
                color: cardBg,
                onSelected: (month) {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      month,
                      1,
                    );
                  });
                },
                itemBuilder: (context) {
                  return List.generate(12, (index) {
                    final month = index + 1;

                    return PopupMenuItem<int>(
                      value: month,
                      child: Text(
                        DateFormat('MMMM').format(DateTime(2026, month)),
                        style: TextStyle(color: textColor),
                      ),
                    );
                  });
                },
                child: Row(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedDate),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: textColor.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: textColor,
                    ),
                    onPressed: _goToPreviousMonth,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: textColor,
                    ),
                    onPressed: _goToNextMonth,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _WeekDayLabel('S'),
              _WeekDayLabel('M'),
              _WeekDayLabel('T'),
              _WeekDayLabel('W'),
              _WeekDayLabel('T'),
              _WeekDayLabel('F'),
              _WeekDayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final int dayNumber = index - startWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final DateTime date = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                dayNumber,
              );

              final bool isSelected = _isSameDay(date, _selectedDate);
              final bool isToday = _isSameDay(date, DateTime.now());
              final bool hasEvent = _hasEventOnDate(date);
              final bool isPast = _isPastDay(date);

              Color bgColor = Colors.transparent;
              Color dayTextColor = textColor;
              FontWeight fontWeight = FontWeight.normal;

              if (isSelected) {
                bgColor = AppColors.primary;
                dayTextColor = AppColors.background;
                fontWeight = FontWeight.bold;
              } else if (hasEvent) {
                bgColor = Colors.redAccent;
                dayTextColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else if (isToday) {
                bgColor = AppColors.primary.withOpacity(0.18);
                dayTextColor = AppColors.primary;
                fontWeight = FontWeight.bold;
              } else if (isPast) {
                dayTextColor = AppColors.textMuted.withOpacity(0.45);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: isToday && !isSelected && !hasEvent
                            ? Border.all(
                          color: AppColors.primary,
                          width: 1,
                        )
                            : null,
                      ),
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: dayTextColor,
                          fontWeight: fontWeight,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    // Nếu ngày đang chọn cũng có sự kiện thì hiển thị chấm đỏ nhỏ
                    if (hasEvent && isSelected)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearView(Color textColor) {
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final int month = index + 1;

          final bool monthHasEvent = EventStorage.userEvents.any((event) {
            try {
              final DateTime eventDate =
              DateFormat('yyyy-MM-dd HH:mm').parse(event.startTime);

              return eventDate.year == _selectedDate.year &&
                  eventDate.month == month;
            } catch (_) {
              return false;
            }
          });

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  month,
                  1,
                );
                _isYearView = false;
              });
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: monthHasEvent
                    ? Colors.redAccent.withOpacity(0.22)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: monthHasEvent
                    ? Border.all(
                  color: Colors.redAccent,
                  width: 1,
                )
                    : null,
              ),
              child: Text(
                DateFormat('MMMM').format(DateTime(_selectedDate.year, month)),
                style: TextStyle(
                  color: monthHasEvent ? Colors.redAccent : textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventHeader(Color textColor, int count) {
    if (_isYearView) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Sự kiện ngày ${DateFormat('dd/MM').format(_selectedDate)}",
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "$count sự kiện",
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
      List<EventModel> events,
      Color cardBg,
      Color textColor,
      ) {
    if (_isYearView) return const SizedBox();

    return Expanded(
      child: events.isEmpty
          ? const Center(
        child: Text(
          "Không có sự kiện nào",
          style: TextStyle(
            color: AppColors.textMuted,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final EventModel e = events[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailScreen(
                      event: e,
                      onEventUpdated: _refreshCalendar,
                    ),
                  ),
                );
              },
              leading: Text(
                e.sticker,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(
                e.title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                "${e.startTime.split(' ')[1]} - ${e.location}",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () async {
                  EventStorage.userEvents.remove(e);
                  await EventStorage.saveEvents();

                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekDayLabel extends StatelessWidget {
  final String text;

  const _WeekDayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}