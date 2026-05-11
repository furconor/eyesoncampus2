import 'user_model.dart';
export 'user_model.dart';

class AppMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isSystem;

  AppMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isSystem = false,
  });
}

class EventMessage {
  final String id;
  final String eventId;
  final User sender;
  final String text;
  final DateTime timestamp;
  final String? imageUrl;
  final String? videoUrl;
  int likesCount;
  int repliesCount;
  bool isLiked;

  EventMessage({
    required this.id,
    required this.eventId,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.imageUrl,
    this.videoUrl,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isLiked = false,
  });
}

class Conversation {
  final String id;
  final User otherUser;
  final List<AppMessage> messages;
  final int unreadCount;
  final bool isNewMatch;
  final String locationTag;

  Conversation({
    required this.id,
    required this.otherUser,
    required this.messages,
    this.unreadCount = 0,
    this.isNewMatch = false,
    this.locationTag = '',
  });

  AppMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

enum NotificationType { look, match, message, system, achievement }

class AppNotification {
  final String id;
  final NotificationType type;
  final User? relatedUser;
  final String title;
  final String message;
  final String location;
  final DateTime timestamp;
  final bool isNew;
  final String? systemIcon;

  AppNotification({
    required this.id,
    required this.type,
    this.relatedUser,
    required this.title,
    required this.message,
    required this.location,
    required this.timestamp,
    this.isNew = true,
    this.systemIcon,
  });

  AppNotification copyWith({
    bool? isNew,
  }) {
    return AppNotification(
      id: id,
      type: type,
      relatedUser: relatedUser,
      title: title,
      message: message,
      location: location,
      timestamp: timestamp,
      isNew: isNew ?? this.isNew,
      systemIcon: systemIcon,
    );
  }
}

class University {
  final String id;
  final String name;
  final String? domain;
  final String? logoUrl;

  University({
    required this.id,
    required this.name,
    this.domain,
    this.logoUrl,
  });
}

class Venue {
  final String id;
  final String name;
  final String icon;
  final int peopleCount;
  final bool isHot;
  final double heatLevel; // 0.0 to 1.0
  final double latitude;
  final double longitude;
  final double radius;
  final String? universityId;
  final String? category;
  final String? imageUrl;

  Venue({
    required this.id,
    required this.name,
    required this.icon,
    required this.peopleCount,
    this.isHot = false,
    required this.heatLevel,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.radius = 100.0,
    this.universityId,
    this.category,
    this.imageUrl,
  });

  Venue copyWith({
    String? id,
    String? name,
    String? icon,
    int? peopleCount,
    bool? isHot,
    double? heatLevel,
    double? latitude,
    double? longitude,
    double? radius,
    String? universityId,
    String? category,
    String? imageUrl,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      peopleCount: peopleCount ?? this.peopleCount,
      isHot: isHot ?? this.isHot,
      heatLevel: heatLevel ?? this.heatLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      universityId: universityId ?? this.universityId,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String imageUrl;
  final int attendeesCount;
  final bool isJoined;
  final bool isLive;
  final String? createdBy;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? category;
  final List<User>? attendeePreviews; // For avatar stack

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.imageUrl,
    this.attendeesCount = 0,
    this.isJoined = false,
    this.isLive = false,
    this.createdBy,
    this.startAt,
    this.endAt,
    this.category,
    this.attendeePreviews,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? date,
    String? imageUrl,
    int? attendeesCount,
    bool? isJoined,
    bool? isLive,
    String? createdBy,
    DateTime? startAt,
    DateTime? endAt,
    String? category,
    List<User>? attendeePreviews,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      isJoined: isJoined ?? this.isJoined,
      isLive: isLive ?? this.isLive,
      createdBy: createdBy ?? this.createdBy,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      category: category ?? this.category,
      attendeePreviews: attendeePreviews ?? this.attendeePreviews,
    );
  }
}
