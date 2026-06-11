class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int requiredMinutes;
  final int requiredDays;
  bool isUnlocked;

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.requiredMinutes = 0,
    this.requiredDays = 0,
    this.isUnlocked = false,
  });
}

class AchievementProvider {
  static List<AchievementModel> list = [
    AchievementModel(id: '1', title: 'Khởi đầu', description: 'Tập trung 5 phút đầu tiên', emoji: '🌱', requiredMinutes: 5),
    AchievementModel(id: '2', title: 'Tập trung sâu', description: 'Hoàn thành phiên 25 phút', emoji: '🧘', requiredMinutes: 25),
    AchievementModel(id: '3', title: 'Kiên trì', description: 'Đạt tổng 1 giờ tập trung', emoji: '🔥', requiredMinutes: 60),
    AchievementModel(id: '4', title: 'Chuyên gia', description: 'Đạt tổng 5 giờ tập trung', emoji: '🎓', requiredMinutes: 300),
    AchievementModel(id: '5', title: 'Focus Master', description: 'Đạt tổng 10 giờ tập trung', emoji: '🏆', requiredMinutes: 600),
    AchievementModel(id: '6', title: 'Người mới', description: 'Đăng nhập đủ 1 ngày', emoji: '👋', requiredDays: 1),
    AchievementModel(id: '7', title: 'Thói quen', description: 'Đăng nhập đủ 7 ngày liên tiếp', emoji: '📅', requiredDays: 7),
    // ... tạo thêm đến 50 cái bằng loop nếu cần, ở đây mock vài cái tiêu biểu
  ];

  static void checkAchievements(int totalMinutes, int streakDays) {
    for (var a in list) {
      if (a.requiredMinutes > 0 && totalMinutes >= a.requiredMinutes) a.isUnlocked = true;
      if (a.requiredDays > 0 && streakDays >= a.requiredDays) a.isUnlocked = true;
    }
  }

  static List<AchievementModel> getFeatured() => list.where((a) => a.isUnlocked).take(3).toList();
}