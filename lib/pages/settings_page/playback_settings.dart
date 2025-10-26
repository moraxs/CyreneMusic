import 'package:flutter/material.dart';
import '../../services/audio_quality_service.dart';
import '../../models/song_detail.dart';

/// 播放设置组件
class PlaybackSettings extends StatelessWidget {
  const PlaybackSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '播放'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.high_quality),
            title: const Text('音质选择'),
            subtitle: Text(
              '${AudioQualityService().getQualityName()} - ${AudioQualityService().getQualityDescription()}'
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAudioQualityDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    final currentQuality = AudioQualityService().currentQuality;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择音质'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AudioQuality>(
              title: const Text('标准音质'),
              subtitle: const Text('128kbps，节省流量'),
              value: AudioQuality.standard,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('极高音质'),
              subtitle: const Text('320kbps，推荐'),
              value: AudioQuality.exhigh,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            RadioListTile<AudioQuality>(
              title: const Text('无损音质'),
              subtitle: const Text('FLAC，音质最佳'),
              value: AudioQuality.lossless,
              groupValue: currentQuality,
              onChanged: (value) {
                if (value != null) {
                  AudioQualityService().setQuality(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('音质设置已更新'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

