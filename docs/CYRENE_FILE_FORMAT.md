# .cyrene 文件格式规范

## 📝 概述

`.cyrene` 是 Cyrene Music 的专有缓存文件格式，用于存储加密的音乐数据和元数据。

**用途：**
- 音乐缓存文件（`{来源}_{歌曲ID}.cyrene`）
- 缓存索引文件（`cache_index.cyrene`）

**特点：**
- ✅ 统一的扩展名
- ✅ 全部加密存储
- ✅ 无法直接播放或查看

## 🔧 文件结构

### 二进制布局

```
┌───────────────────────────────────────────────┐
│ 偏移    │ 长度         │ 内容                 │
├───────────────────────────────────────────────┤
│ 0x00    │ 4 bytes      │ 元数据长度（大端序） │
│ 0x04    │ N bytes      │ 元数据 JSON          │
│ 0x04+N  │ 剩余所有字节  │ 加密的音频数据       │
└───────────────────────────────────────────────┘
```

### 字段详解

#### 1. 元数据长度（4 字节）

- **格式：** 32位无符号整数，大端序（Big-Endian）
- **范围：** 0 - 4,294,967,295
- **用途：** 指示后续元数据 JSON 的字节长度

**编码示例：**
```dart
// 如果元数据长度为 256 字节
bytes[0] = 0x00;  // (256 >> 24) & 0xFF
bytes[1] = 0x00;  // (256 >> 16) & 0xFF
bytes[2] = 0x01;  // (256 >> 8) & 0xFF
bytes[3] = 0x00;  // 256 & 0xFF
```

**解码示例：**
```dart
final metadataLength = (bytes[0] << 24) | 
                       (bytes[1] << 16) | 
                       (bytes[2] << 8) | 
                       bytes[3];
```

#### 2. 元数据 JSON（N 字节）

- **格式：** UTF-8 编码的 JSON 字符串
- **编码：** UTF-8
- **长度：** 由前4字节指定

**JSON 结构：**
```json
{
  "songId": "1234567",
  "songName": "演员",
  "artists": "薛之谦",
  "source": "netease",
  "quality": "exhigh",
  "originalUrl": "http://music.163.com/...",
  "fileSize": 5242880,
  "cachedAt": "2025-10-02T15:30:00.000Z",
  "checksum": "a1b2c3d4e5f6789..."
}
```

**字段类型：**
| 字段 | 类型 | 说明 |
|------|------|------|
| songId | String | 歌曲唯一标识 |
| songName | String | 歌曲名称 |
| artists | String | 艺术家（多个用逗号分隔） |
| source | String | 来源：netease/qq/kugou |
| quality | String | 音质等级 |
| originalUrl | String | 原始下载链接 |
| fileSize | Number | 原始音频大小（字节） |
| cachedAt | String | ISO 8601 时间戳 |
| checksum | String | MD5 校验和（十六进制） |

#### 3. 加密的音频数据（剩余字节）

- **格式：** 二进制音频数据（通常是 MP3/FLAC 等）
- **加密：** XOR 异或加密
- **密钥：** `CyreneMusicCacheKey2025`

**加密算法：**
```dart
Uint8List encryptData(Uint8List data) {
  final keyBytes = utf8.encode('CyreneMusicCacheKey2025');
  final encrypted = Uint8List(data.length);
  
  for (int i = 0; i < data.length; i++) {
    encrypted[i] = data[i] ^ keyBytes[i % keyBytes.length];
  }
  
  return encrypted;
}
```

**特点：**
- 对称加密（加密 = 解密）
- 轻量快速
- 防止直接播放

## 📏 文件大小计算

```
总大小 = 4 + 元数据长度 + 音频数据长度
```

**示例：**
- 元数据：256 字节
- 音频：5,242,880 字节（5 MB）
- 总计：5,243,140 字节（约 5.00 MB）

## 🔐 安全性

### 加密目的

- ✅ 防止缓存文件被直接使用
- ✅ 版权保护（非下载，仅缓存）
- ✅ 确保只能通过应用播放

### 安全级别

- **加密强度：** 低（XOR 加密）
- **保护目标：** 防止普通用户直接使用
- **非目标：** 不用于高强度加密保护

**注意：** XOR 加密可以被逆向，但已足够防止普通用户直接播放缓存文件。

## 🛠️ 读写操作

### 写入 .cyrene 文件

```dart
// 1. 准备元数据
final metadata = {...};
final metadataJson = jsonEncode(metadata);
final metadataBytes = utf8.encode(metadataJson);
final metadataLength = metadataBytes.length;

// 2. 加密音频数据
final encryptedAudio = encryptData(audioData);

// 3. 构建文件
final cyreneFile = BytesBuilder();

// 写入长度（4字节大端序）
cyreneFile.addByte((metadataLength >> 24) & 0xFF);
cyreneFile.addByte((metadataLength >> 16) & 0xFF);
cyreneFile.addByte((metadataLength >> 8) & 0xFF);
cyreneFile.addByte(metadataLength & 0xFF);

// 写入元数据
cyreneFile.add(metadataBytes);

// 写入加密音频
cyreneFile.add(encryptedAudio);

// 4. 保存文件
await File('song.cyrene').writeAsBytes(cyreneFile.toBytes());
```

### 读取 .cyrene 文件

```dart
// 1. 读取文件
final fileData = await File('song.cyrene').readAsBytes();

// 2. 读取元数据长度
final metadataLength = (fileData[0] << 24) |
                       (fileData[1] << 16) |
                       (fileData[2] << 8) |
                       fileData[3];

// 3. 读取元数据
final metadataBytes = fileData.sublist(4, 4 + metadataLength);
final metadataJson = utf8.decode(metadataBytes);
final metadata = jsonDecode(metadataJson);

// 4. 读取加密的音频数据
final encryptedAudio = fileData.sublist(4 + metadataLength);

// 5. 解密音频
final decryptedAudio = decryptData(encryptedAudio);

// 6. 播放
await audioPlayer.play(DeviceFileSource(tempFile));
```

## 🔍 验证文件完整性

### 1. 检查文件头

```dart
bool isValidCyreneFile(File file) {
  final bytes = await file.readAsBytes();
  
  // 至少需要4字节
  if (bytes.length < 4) return false;
  
  final metadataLength = (bytes[0] << 24) | 
                         (bytes[1] << 16) | 
                         (bytes[2] << 8) | 
                         bytes[3];
  
  // 文件大小必须 >= 4 + 元数据长度
  return bytes.length >= 4 + metadataLength;
}
```

### 2. 验证校验和

```dart
// 从元数据中获取原始校验和
final expectedChecksum = metadata['checksum'];

// 计算解密后的音频校验和
final actualChecksum = md5.convert(decryptedAudio).toString();

// 验证
if (expectedChecksum != actualChecksum) {
  throw Exception('文件已损坏');
}
```

## 📊 文件示例

### 文件大小对比

| 格式 | 原始音频 | 元数据 | .cyrene 文件 |
|------|---------|--------|-------------|
| MP3 标准 | 3.5 MB | 256 B | 3.5 MB |
| MP3 极高 | 8.2 MB | 256 B | 8.2 MB |
| FLAC 无损 | 32.1 MB | 256 B | 32.1 MB |

**注意：** 加密不增加文件大小，`.cyrene` 文件大小 ≈ 原始音频大小 + 元数据大小（通常可忽略）。

## 🔄 版本兼容性

### 当前版本：v1.0

- **格式版本：** 1.0
- **向后兼容：** 未来版本可能添加版本字段
- **建议：** 在元数据中添加 `formatVersion` 字段

### 未来扩展

可能的改进：

1. **添加版本号** - 支持格式升级
2. **压缩元数据** - 使用 gzip 压缩 JSON
3. **更强加密** - 使用 AES 加密
4. **签名验证** - 防止文件被篡改
5. **分块存储** - 支持大文件

## ⚠️ 注意事项

1. **大端序** - 元数据长度使用大端序存储
2. **UTF-8 编码** - 元数据必须使用 UTF-8
3. **完整性** - 删除文件时删除对应的缓存索引条目
4. **唯一性** - 同一首歌只能有一个缓存文件

## 📚 参考实现

**完整实现：** `lib/services/cache_service.dart`

---

**版本：** 1.0  
**最后更新：** 2025-10-02  
**状态：** 稳定

