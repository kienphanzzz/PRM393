import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel? task;
  final bool isNewTask;

  const TaskDetailScreen({super.key, this.task, this.isNewTask = false});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _dateController;
  String _priority = 'Medium';
  bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descController = TextEditingController(text: widget.task?.description ?? '');
    _dateController = TextEditingController(text: widget.task?.deadline ?? '');
    _priority = widget.task?.priority ?? 'Medium';
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    if (widget.isNewTask) {
      final newTask = TaskModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        deadline: _dateController.text.trim(),
        priority: _priority,
      );
      TaskStorage.todoTasks.add(newTask);
    } else if (widget.task != null) {
      widget.task!.title = _titleController.text.trim();
      widget.task!.description = _descController.text.trim();
      widget.task!.deadline = _dateController.text.trim();
      widget.task!.priority = _priority;
    }

    await TaskStorage.saveTasks();
    if (mounted) Navigator.pop(context, true);
  }

  void _deleteTask() async {
    if (widget.task != null) {
      TaskStorage.todoTasks.removeWhere((t) => t.id == widget.task!.id);
      await TaskStorage.saveTasks();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          final formattedTime = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
          _dateController.text = "$formattedDate $formattedTime";
        });
      }
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isNewTask ? 'Thêm nhiệm vụ' : 'Chi tiết nhiệm vụ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!widget.isNewTask)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteTask,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Tên nhiệm vụ', textColor),
            _buildTextField(_titleController, 'Nhập tên nhiệm vụ...', cardBg, textColor),
            const SizedBox(height: 20),
            
            _buildLabel('Mô tả', textColor),
            _buildTextField(_descController, 'Thêm chi tiết...', cardBg, textColor, maxLines: 3),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Hạn chót', textColor),
                      GestureDetector(
                        onTap: _selectDateTime,
                        child: AbsorbPointer(
                          child: _buildTextField(_dateController, 'Chọn ngày & giờ', cardBg, textColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Ưu tiên', textColor),
                      _buildPriorityDropdown(cardBg, textColor),
                    ],
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saveTask,
                child: Text(
                  widget.isNewTask ? 'Tạo mới' : 'Cập nhật',
                  style: const TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold),
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
      child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, Color bg, Color txt, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: txt),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown(Color bg, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _priority,
          dropdownColor: bg,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          items: ['High', 'Medium', 'Low'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(color: txt)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _priority = val!),
        ),
      ),
    );
  }
}