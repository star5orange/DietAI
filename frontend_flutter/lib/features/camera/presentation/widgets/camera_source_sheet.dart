import 'package:flutter/material.dart';

/// 「拍照记录」弹窗选项编码（chat_page 相机入口 → CameraPage 参数的契约）。
///
/// source 命名约定：`{food|label}_{camera|gallery}`
/// - 前缀 `food`/`label` → 识别模式：餐食识别（AI 图像分析）/ 包装食品（营养成分表 OCR）
/// - 后缀 `camera`/`gallery` → 图片来源：取景器拍照 / 系统相册
///
/// 解析函数 [isLabel] / [useGallery] 与 CameraPage 的
/// `initialLabelMode` / `autoPickGallery` 参数一一对应。
class CameraSheetSource {
  CameraSheetSource._();

  static const String foodCamera = 'food_camera';
  static const String foodGallery = 'food_gallery';
  static const String labelCamera = 'label_camera';
  static const String labelGallery = 'label_gallery';

  /// 是否包装食品（营养成分表 OCR）模式；null/未知值按餐食识别处理
  static bool isLabel(String? source) => source?.startsWith('label') ?? false;

  /// 是否走系统相册（autoPickGallery）；null/未知值按取景器拍照处理
  static bool useGallery(String? source) =>
      source?.endsWith('gallery') ?? false;
}

/// 「拍照记录」来源选择弹窗内容（showModalBottomSheet 的 builder 部分）。
///
/// 分组展示拍照目的（记录饮食 / 包装食品）× 来源（拍照 / 相册），
/// 选中后通过 [onSelect] 回传 CameraSheetSource 编码，由调用方 pop 并跳转。
class CameraSourceSheet extends StatelessWidget {
  const CameraSourceSheet({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 小屏/窄视口下 4 个选项可能超出可用高度，包一层滚动防 overflow
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                '拍照记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                '记录饮食',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ListTile(
              key: const Key('sheet_food_camera'),
              leading: const Icon(Icons.restaurant),
              title: const Text('拍食物'),
              subtitle: const Text('拍摄餐食，AI 自动识别营养'),
              onTap: () => onSelect(CameraSheetSource.foodCamera),
            ),
            ListTile(
              key: const Key('sheet_food_gallery'),
              leading: const Icon(Icons.photo_library),
              title: const Text('食物图片'),
              subtitle: const Text('从相册选择已有照片'),
              onTap: () => onSelect(CameraSheetSource.foodGallery),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                '包装食品',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ListTile(
              key: const Key('sheet_label_camera'),
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('拍营养成分表'),
              subtitle: const Text('拍摄包装上的营养成分表，OCR 提取'),
              onTap: () => onSelect(CameraSheetSource.labelCamera),
            ),
            ListTile(
              key: const Key('sheet_label_gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('包装图片'),
              subtitle: const Text('从相册选择包装照片'),
              onTap: () => onSelect(CameraSheetSource.labelGallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
