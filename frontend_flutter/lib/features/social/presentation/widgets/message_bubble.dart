import 'package:flutter/material.dart';
import '../../domain/message_models.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final int currentUserId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.senderId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFF2BAF74) : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: _buildMessageContent(context, isMine),
            ),
          ),
          const SizedBox(width: 8),
          if (isMine) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isMine) {
    switch (message.messageType) {
      case 'food_card':
        return _buildFoodCard(context, isMine);
      case 'poke':
        return _buildPokeMessage(context, isMine);
      case 'image':
        return _buildImageMessage(context, isMine);
      default:
        return _buildTextMessage(isMine);
    }
  }

  Widget _buildTextMessage(bool isMine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            color: isMine ? Colors.white70 : Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodCard(BuildContext context, bool isMine) {
    final extraData = message.extraData;
    final foodName = extraData?['food_name'] as String? ?? '食物';
    final calories = extraData?['calories'] as int? ?? 0;
    final protein = extraData?['protein'] as int? ?? 0;
    final fat = extraData?['fat'] as int? ?? 0;
    final carbs = extraData?['carbs'] as int? ?? 0;
    final imageUrl = extraData?['image_url'] as String?;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 食物图片
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant,
                        size: 48, color: Colors.grey),
                  );
                },
              ),
            ),
          // 食物信息
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant,
                        size: 16, color: Color(0xFF2BAF74)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        foodName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$calories kcal',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2BAF74),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildNutrientTag('蛋白', protein, 'g', Colors.blue),
                    const SizedBox(width: 8),
                    _buildNutrientTag('脂肪', fat, 'g', Colors.orange),
                    const SizedBox(width: 8),
                    _buildNutrientTag('碳水', carbs, 'g', Colors.purple),
                  ],
                ),
              ],
            ),
          ),
          // 时间
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientTag(String label, int value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value$unit',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPokeMessage(BuildContext context, bool isMine) {
    final extraData = message.extraData;
    final pokeType = extraData?['poke_type'] as String? ?? 'general';

    String pokeText;
    IconData pokeIcon;
    Color pokeColor;

    switch (pokeType) {
      case 'water':
        pokeText = '💧 提醒你喝水';
        pokeIcon = Icons.water_drop;
        pokeColor = Colors.blue;
        break;
      case 'eat':
        pokeText = '🍽️ 提醒你吃饭';
        pokeIcon = Icons.restaurant;
        pokeColor = Colors.orange;
        break;
      default:
        pokeText = '👋 戳了戳你';
        pokeIcon = Icons.waving_hand;
        pokeColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(pokeIcon, color: pokeColor, size: 20),
            const SizedBox(width: 8),
            Text(
              pokeText,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            color: isMine ? Colors.white70 : Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage(BuildContext context, bool isMine) {
    final imageUrl = message.content;
    final extraData = message.extraData;
    final thumbnailUrl = extraData?['thumbnail_url'] as String?;
    final displayUrl = thumbnailUrl ?? imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图片
        GestureDetector(
          onTap: () => _showImagePreview(context, imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              displayUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isMine
                            ? Colors.white70
                            : (Colors.grey[600] ?? Colors.grey),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 时间
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            color: isMine ? Colors.white70 : Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // 图片
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 300,
                      height: 300,
                      child: Center(
                        child: Icon(Icons.broken_image,
                            size: 64, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 关闭按钮
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[200],
      backgroundImage: message.senderAvatarUrl != null
          ? NetworkImage(message.senderAvatarUrl!)
          : null,
      child: message.senderAvatarUrl == null
          ? const Icon(Icons.person, size: 18, color: Colors.grey)
          : null,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
