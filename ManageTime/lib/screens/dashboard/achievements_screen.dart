import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/achievement_model.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = ThemeController.isDark;
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Kho Huy Hiệu Focus', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: AchievementProvider.list.length,
        itemBuilder: (context, index) {
          final item = AchievementProvider.list[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: item.isUnlocked ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(item.emoji, style: TextStyle(fontSize: 30, color: item.isUnlocked ? null : Colors.grey.withOpacity(0.5)))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.isUnlocked ? textColor : Colors.grey)),
                      const SizedBox(height: 4),
                      Text(item.description, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (item.isUnlocked) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}