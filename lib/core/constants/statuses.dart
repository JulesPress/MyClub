class EventStatus {
  static const scheduled = 'scheduled';
  static const ongoing = 'ongoing';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const values = [
    scheduled,
    ongoing,
    completed,
    cancelled,
  ];
}

class TaskStatus {
  static const pending = 'pending';
  static const claimed = 'claimed';
  static const done = 'done';
  static const cancelled = 'cancelled';
  static const open = 'open';

  static const values = [
    pending,
    claimed,
    open,
    done,
    cancelled,
  ];
}

class TaskType {
  static const personal = 'personal';
  static const general = 'general';

  static const values = [
    personal,
    general,
  ];
}