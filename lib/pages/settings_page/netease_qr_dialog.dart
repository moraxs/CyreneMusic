import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/netease_login_service.dart';

/// 显示网易云扫码登录对话框
Future<bool?> showNeteaseQrDialog(BuildContext context, int userId) async {
  NeteaseQrCreateResult? created;
  try {
    created = await NeteaseLoginService().createQrKey();
  } catch (e) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('获取二维码失败: $e')),
    );
    return null;
  }

  if (!context.mounted) return null;

  final success = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => NeteaseQrDialog(
      userId: userId,
      qrUrl: created!.qrUrl,
      qrKey: created.key,
    ),
  );

  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('网易云账号绑定成功')),
    );
  }

  return success;
}

/// 网易云扫码对话框
class NeteaseQrDialog extends StatefulWidget {
  final int userId;
  final String qrUrl;
  final String qrKey;
  
  const NeteaseQrDialog({
    super.key,
    required this.userId,
    required this.qrUrl,
    required this.qrKey,
  });

  @override
  State<NeteaseQrDialog> createState() => _NeteaseQrDialogState();
}

class _NeteaseQrDialogState extends State<NeteaseQrDialog> {
  Timer? _timer;
  String _statusText = '请使用网易云音乐 App 扫码登录';
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (_completed) return;
      try {
        final r = await NeteaseLoginService().checkQrStatus(
          key: widget.qrKey,
          userId: widget.userId,
        );
        String nextStatus = _statusText;
        bool success = false;
        switch (r.code) {
          case 800:
            nextStatus = '二维码已过期，请关闭重试';
            break;
          case 801:
            nextStatus = '等待扫码...';
            break;
          case 802:
            nextStatus = '待确认，请在手机上确认登录';
            break;
          case 803:
            success = true;
            _completed = true;
            break;
          default:
            nextStatus = r.message ?? '状态未知';
        }
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(true);
        } else if (nextStatus != _statusText) {
          setState(() {
            _statusText = nextStatus;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code),
          SizedBox(width: 8),
          Text('绑定网易云账号')
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Center(
                child: QrImageView(
                  data: widget.qrUrl,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              widget.qrUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

