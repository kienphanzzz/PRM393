class TaskModel {
  String id;
  String title;
  String deadline;
  String priority;
  bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    this.isCompleted = false,
  });
}

class TaskStorage {
  static List<TaskModel> todoTasks = [
    TaskModel(id: '1', title: 'Finish project report', deadline: 'Due at 3:00 PM', priority: 'High'),
    TaskModel(id: '2', title: 'Team standup meeting', deadline: '4:30 PM - 5:00 PM', priority: 'Medium'),
    TaskModel(id: '3', title: 'Evening workout', deadline: '6:00 PM - 7:00 PM', priority: 'Low'),
  ];
}