import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel? task;
  final VoidCallback onTaskUpdated;

  const TaskDetailScreen({super.key, this.task, required this.onTaskUpdated});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _titleController = TextEditingController();
  final _deadlineController = TextEditingController();
  String _selectedPriority = 'Medium';
  final bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _deadlineController.text = widget.task!.deadline;
      _selectedPriority = widget.task!.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty || _deadlineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.orange, content: Text('Please fill all info')),
      );
      return;
    }

    if (widget.task == null) {
      TaskStorage.todoTasks.add(
        TaskModel(
          id: DateTime.now().toString(),
          title: _titleController.text.trim(),
          deadline: _deadlineController.text.trim(),
          priority: _selectedPriority,
        ),
      );
    } else {
      widget.task!.title = _titleController.text.trim();
      widget.task!.deadline = _deadlineController.text.trim();
      widget.task!.priority = _selectedPriority;
    }

    widget.onTaskUpdated();
    Navigator.pop(context);
  }

  void _deleteTask() {
    if (widget.task != null) {
      TaskStorage.todoTasks.removeWhere((item) => item.id == widget.task!.id);
      widget.onTaskUpdated();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg = _isDark ? AppColors.background : Colors.grey.shade100;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    Color textColor = _isDark ? Colors.white : Colors.black87;
    bool isEditMode = widget.task != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (isEditMode)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
                      onPressed: _deleteTask,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isEditMode ? 'Task Details & Action' : 'Add New Task',
                style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              Text('Task Title Name', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'E.g., Read advanced flutter tech book',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Text('Set Deadline Target', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _deadlineController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'E.g., Due tomorrow at 5:00 PM',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Text('Set Priority Level', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(
                children: ['Low', 'Medium', 'High'].map((p) {
                  bool isSelected = _selectedPriority == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPriority = p;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          p,
                          style: TextStyle(
                            color: isSelected ? AppColors.background : textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveTask,
                  child: Text(
                    isEditMode ? 'Save & Update Details' : 'Create Task Now',
                    style: const TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}