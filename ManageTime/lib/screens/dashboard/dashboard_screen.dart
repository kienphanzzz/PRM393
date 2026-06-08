import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, this.userName = 'User'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 2;
  late String _timeString;
  late String _dateString;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeString = DateFormat('HH:mm:ss').format(DateTime.now());
    _dateString = DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(now);
      _dateString = DateFormat('EEEE, MMM dd, yyyy').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${widget.userName}!', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('$_dateString | $_timeString', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Stack(
                    children: [
                      const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: CircleAvatar(radius: 4, backgroundColor: Colors.red.shade600),
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 30),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(Icons.check_circle_outline, 'Tasks', '5 pending', Colors.blue),
                  _buildStatCard(Icons.shutter_speed, 'Focus', '2h 15m today', Colors.purple),
                  _buildStatCard(Icons.calendar_today, 'Events', '3 upcoming', Colors.green),
                  _buildStatCard(Icons.trending_up, 'Progress', '78% weekly', Colors.orange),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Today's Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View all', style: TextStyle(color: AppColors.primary)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              _buildTaskItem(Icons.description, 'Finish project report', 'Due at 3:00 PM', Colors.blue.withOpacity(0.2)),
              _buildTaskItem(Icons.groups, 'Team standup meeting', '4:30 PM - 5:00 PM', Colors.green.withOpacity(0.2)),
              _buildTaskItem(Icons.fitness_center, 'Evening workout', '6:00 PM - 7:00 PM', Colors.purple.withOpacity(0.2)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBg,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.hourglass_empty), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(radius: 18, backgroundColor: iconColor.withOpacity(0.2), child: Icon(icon, color: iconColor, size: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaskItem(IconData icon, String title, String time, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: iconBg, child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}