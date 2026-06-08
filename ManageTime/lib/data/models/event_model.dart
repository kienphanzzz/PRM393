class EventModel {
  String id;
  String title;
  String timeLocation;
  String type;

  EventModel({
    required this.id,
    required this.title,
    required this.timeLocation,
    required this.type,
  });
}

class EventStorage {
  static List<EventModel> todayEvents = [
    EventModel(id: 'e1', title: 'Họp Hội đồng Đường lối dự án', timeLocation: '09:30 AM - Room 402', type: 'Meeting'),
    EventModel(id: 'e2', title: 'Nộp báo cáo tiến độ SWT301', timeLocation: 'Before 11:59 PM - Online', type: 'Deadline'),
    EventModel(id: 'e3', title: 'Đi tập Gym (Ngực + Tay sau)', timeLocation: '06:00 PM - Gym Center', type: 'Fitness'),
  ];
}