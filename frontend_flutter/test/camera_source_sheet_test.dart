// 「拍照记录」弹窗分组逻辑单测：
// 1) CameraSheetSource 编码 → CameraPage 参数（initialLabelMode / autoPickGallery）的解析矩阵
// 2) CameraSourceSheet 弹窗内容：分组标题、4 个选项、点按回传编码
//
// 运行：cd frontend_flutter && flutter test test/camera_source_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dietai_flutter/features/camera/presentation/widgets/camera_source_sheet.dart';

void main() {
  group('CameraSheetSource 解析矩阵（编码契约）', () {
    test('四个合法选项 → (labelMode, gallery) 组合', () {
      final cases = <String, (bool, bool)>{
        CameraSheetSource.foodCamera: (false, false), // 取景器拍餐食
        CameraSheetSource.foodGallery: (false, true), // 相册选餐食
        CameraSheetSource.labelCamera: (true, false), // 取景器拍包装
        CameraSheetSource.labelGallery: (true, true), // 相册选包装
      };
      cases.forEach((source, expected) {
        expect(CameraSheetSource.isLabel(source), expected.$1,
            reason: 'isLabel($source)');
        expect(CameraSheetSource.useGallery(source), expected.$2,
            reason: 'useGallery($source)');
      });
    });

    test('健壮性：null / 空 / 未知值按餐食 + 取景器兜底', () {
      for (final bad in [null, '', 'abc', 'food', 'gallery_only']) {
        expect(CameraSheetSource.isLabel(bad), isFalse,
            reason: 'isLabel($bad)');
        expect(CameraSheetSource.useGallery(bad), isFalse,
            reason: 'useGallery($bad)');
      }
    });

    test('前缀/后缀规则按约定生效（编码注释与实现一致）', () {
      // 前缀 label* → OCR 模式；后缀 *gallery → 相册
      expect(CameraSheetSource.isLabel('label_anything'), isTrue);
      expect(CameraSheetSource.useGallery('anything_gallery'), isTrue);
    });

    test('常量命名与解析互恰（防常量改名漂移）', () {
      expect(CameraSheetSource.isLabel(CameraSheetSource.labelCamera), isTrue);
      expect(CameraSheetSource.isLabel(CameraSheetSource.labelGallery), isTrue);
      expect(CameraSheetSource.isLabel(CameraSheetSource.foodCamera), isFalse);
      expect(CameraSheetSource.isLabel(CameraSheetSource.foodGallery), isFalse);
      expect(
          CameraSheetSource.useGallery(CameraSheetSource.foodGallery), isTrue);
      expect(
          CameraSheetSource.useGallery(CameraSheetSource.labelGallery), isTrue);
      expect(
          CameraSheetSource.useGallery(CameraSheetSource.foodCamera), isFalse);
      expect(
          CameraSheetSource.useGallery(CameraSheetSource.labelCamera), isFalse);
    });
  });

  group('CameraSourceSheet 弹窗内容', () {
    // 直接 pump 组件本身（不走 showModalBottomSheet 路由）：
    // modal 路由的 Future 返回链路在 FakeAsync 测试环境下不可靠（tap 后 await 悬挂），
    // 而弹窗的「分组逻辑」本体 = 组件渲染 + 点按回传编码，用回调捕获即可覆盖；
    // pop 返回值到 CameraPage 参数的映射已由上面的解析矩阵测试覆盖。
    Future<void> pumpSheet(
        WidgetTester tester, ValueChanged<String> onSelect) async {
      // 默认 800x600 视口装不下 4 个 ListTile（RenderFlex overflow），放大测试视口
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CameraSourceSheet(onSelect: onSelect)),
        ),
      );
    }

    testWidgets('标题 + 两组分组 + 四个选项齐全', (tester) async {
      await pumpSheet(tester, (_) {});
      expect(find.text('拍照记录'), findsOneWidget);
      expect(find.text('记录饮食'), findsOneWidget);
      expect(find.text('包装食品'), findsOneWidget);
      expect(find.text('拍食物'), findsOneWidget);
      expect(find.text('食物图片'), findsOneWidget);
      expect(find.text('拍营养成分表'), findsOneWidget);
      expect(find.text('包装图片'), findsOneWidget);
    });

    testWidgets('点按回传对应编码：拍食物 → food_camera', (tester) async {
      String? selected;
      await pumpSheet(tester, (s) => selected = s);
      await tester.tap(find.byKey(const Key('sheet_food_camera')));
      await tester.pump();
      expect(selected, 'food_camera');
    });

    testWidgets('点按回传对应编码：食物图片 → food_gallery', (tester) async {
      String? selected;
      await pumpSheet(tester, (s) => selected = s);
      await tester.tap(find.byKey(const Key('sheet_food_gallery')));
      await tester.pump();
      expect(selected, 'food_gallery');
    });

    testWidgets('点按回传对应编码：拍营养成分表 → label_camera', (tester) async {
      String? selected;
      await pumpSheet(tester, (s) => selected = s);
      await tester.tap(find.byKey(const Key('sheet_label_camera')));
      await tester.pump();
      expect(selected, 'label_camera');
    });

    testWidgets('点按回传对应编码：包装图片 → label_gallery', (tester) async {
      String? selected;
      await pumpSheet(tester, (s) => selected = s);
      await tester.tap(find.byKey(const Key('sheet_label_gallery')));
      await tester.pump();
      expect(selected, 'label_gallery');
    });
  });
}
