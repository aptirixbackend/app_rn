// Wire models for chat, shared by the REST hydrate and the WebSocket stream
// (both speak the same JSON shape the backend emits).

int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

DateTime _asTime(dynamic v) =>
    DateTime.tryParse('${v ?? ''}')?.toLocal() ?? DateTime.now();

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    this.imageUrl = '',
    this.messageType = 'text',
    this.status = 'sent',
    this.propertyId,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String imageUrl;
  final String messageType;
  final String status; // sending | sent | delivered | read
  final String? propertyId;
  final DateTime createdAt;

  bool get isImage => messageType == 'image' && imageUrl.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] ?? '').toString(),
        senderId: (j['sender_id'] ?? '').toString(),
        receiverId: (j['receiver_id'] ?? '').toString(),
        text: (j['message'] ?? j['body'] ?? '').toString(),
        imageUrl: (j['image_url'] ?? '').toString(),
        messageType: (j['message_type'] ?? 'text').toString(),
        status: (j['status'] ?? 'sent').toString(),
        propertyId: (j['property_id'])?.toString(),
        createdAt: _asTime(j['timestamp'] ?? j['created_at']),
      );

  ChatMessage copyWith({String? id, String? status}) => ChatMessage(
        id: id ?? this.id,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        imageUrl: imageUrl,
        messageType: messageType,
        status: status ?? this.status,
        propertyId: propertyId,
        createdAt: createdAt,
      );
}

class ChatPartner {
  ChatPartner({
    required this.userId,
    required this.userName,
    this.userImage,
    this.phone,
    this.online = false,
  });

  final String userId;
  final String userName;
  final String? userImage;
  final String? phone;
  final bool online;

  factory ChatPartner.fromJson(Map<String, dynamic> j) => ChatPartner(
        userId: (j['user_id'] ?? '').toString(),
        userName: (j['user_name'] ?? 'RentoRent User').toString(),
        userImage: (j['user_image'])?.toString(),
        phone: (j['phone'])?.toString(),
        online: j['online'] == true,
      );
}

class Conversation {
  Conversation({
    required this.userId,
    required this.userName,
    required this.lastMessage,
    required this.lastSenderId,
    required this.unread,
    this.userImage,
    this.lastTime,
  });

  final String userId;
  final String userName;
  final String? userImage;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastTime;
  final int unread;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        userId: (j['user_id'] ?? '').toString(),
        userName: (j['user_name'] ?? 'RentoRent User').toString(),
        userImage: (j['user_image'])?.toString(),
        lastMessage: (j['last_message'] ?? '').toString(),
        lastSenderId: (j['last_sender_id'] ?? '').toString(),
        lastTime: j['last_message_time'] == null
            ? null
            : _asTime(j['last_message_time']),
        unread: _asInt(j['unread_count']),
      );
}
