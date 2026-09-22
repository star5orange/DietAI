import 'package:flutter/material.dart';
import 'package:dietai_flutter/core/services/api_service.dart';

/// 设备绑定页面 — 输入 6 位配对码绑定 ESP32 硬件
class DeviceBindingPage extends StatefulWidget {
  const DeviceBindingPage({super.key});

  @override
  State<DeviceBindingPage> createState() => _DeviceBindingPageState();
}

class _DeviceBindingPageState extends State<DeviceBindingPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isBound = false;
  Map<String, dynamic>? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceStatus() async {
    try {
      final response = await ApiService().dio.get('/device/status');
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        setState(() {
          _isBound = true;
          _deviceInfo = data['data'] as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmPairing() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 6 位配对码')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService().dio.post(
        '/device/confirm-pairing',
        data: {'pairing_code': code},
      );
      final data = response.data;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 设备绑定成功！')),
        );
        setState(() {
          _isBound = true;
          _isLoading = false;
        });
        _loadDeviceStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? '绑定失败')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unbindDevice() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().dio.post('/device/unbind');
      final data = response.data;
      if (data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已解绑')),
        );
        setState(() {
          _isBound = false;
          _deviceInfo = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解绑失败: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备绑定'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isBound ? _buildBoundView() : _buildPairingView(),
      ),
    );
  }

  Widget _buildPairingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '绑定新设备',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '在硬件屏幕上查看 6 位配对码，输入下方完成绑定。',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _confirmPairing,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('确认绑定', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildBoundView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '已绑定设备',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.devices, size: 32, color: Color(0xFF0F3460)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '设备 ${_deviceInfo?['device_key']?.toString().substring(0, 8) ?? '---'}...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ID: ${_deviceInfo?['device_id'] ?? '-'}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _unbindDevice,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('解绑设备', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
