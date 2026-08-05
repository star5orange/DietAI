import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'api_service.dart';

/// 文本转语音服务
class TtsService {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentText;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 当前播报文本
  String? get currentText => _currentText;

  /// 播放文本转语音
  Future<void> speak(String text, {String voiceType = 'zh_female'}) async {
    if (text.trim().isEmpty) return;

    try {
      // 如果正在播放相同文本，停止当前播放
      if (_isPlaying && _currentText == text) {
        await stop();
        return;
      }

      // 停止当前播放
      if (_isPlaying) {
        await stop();
      }

      _currentText = text;
      _isPlaying = true;

      // 调用 TTS API 获取音频
      final response = await _apiService.dio.post(
        '/voice/tts',
        data: FormData.fromMap({
          'text': text,
          'voice_type': voiceType,
        }),
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // 保存音频到临时文件
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
            '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(response.data as List<int>);

        // 播放音频
        await _audioPlayer.play(DeviceFileSource(audioFile.path));

        // 监听播放完成
        _audioPlayer.onPlayerComplete.listen((_) {
          _isPlaying = false;
          _currentText = null;
        });

        // 监听播放错误
        _audioPlayer.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.stopped || state == PlayerState.completed) {
            _isPlaying = false;
            _currentText = null;
          }
        });
      }
    } catch (e) {
      _isPlaying = false;
      _currentText = null;
      throw Exception('语音播报失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentText = null;
  }

  /// 释放资源
  void dispose() {
    _audioPlayer.dispose();
  }
}
