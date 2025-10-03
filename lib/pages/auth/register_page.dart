import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';

/// 注册页面
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _qqNumberController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _codeSent = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _qqNumberController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 将 QQ 号拼接为完整的 QQ 邮箱地址
  String _getFullEmail() {
    return '${_qqNumberController.text.trim()}@qq.com';
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
      _codeSent = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _codeSent = false;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    if (_qqNumberController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 QQ 号和用户名')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().sendRegisterCode(
      email: _getFullEmail(),
      username: _usernameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        _startCountdown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入验证码')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().register(
      email: _getFullEmail(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      code: _codeController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
        Navigator.pop(context); // 返回登录页面
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('注册账号'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // QQ 号输入
                  TextFormField(
                    controller: _qqNumberController,
                    decoration: InputDecoration(
                      labelText: 'QQ 号',
                      prefixIcon: const Icon(Icons.chat_bubble_outline),
                      suffixText: '@qq.com',
                      suffixStyle: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: const OutlineInputBorder(),
                      helperText: '将使用 QQ 邮箱接收验证码',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入 QQ 邮箱';
                      }
                      // 验证是否为纯数字
                      if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                        return 'QQ 号应为纯数字';
                      }
                      // 验证 QQ 号长度（通常 5-11 位）
                      if (value.trim().length < 5 || value.trim().length > 11) {
                        return 'QQ 号长度应为 5-11 位';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    onChanged: (value) {
                      // 实时更新，显示完整邮箱地址提示
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // 显示完整的 QQ 邮箱地址
                  if (_qqNumberController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '注册邮箱：${_getFullEmail()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // 用户名
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      helperText: '4-20个字符，仅字母数字下划线',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入用户名';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(value)) {
                        return '用户名格式不正确';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // 密码
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      helperText: '至少8个字符',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 8) {
                        return '密码至少8个字符';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // 确认密码
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请确认密码';
                      }
                      if (value != _passwordController.text) {
                        return '两次密码不一致';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),

                  // 验证码输入和发送按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: FilledButton(
                          onPressed: _codeSent || _isLoading ? null : _sendCode,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _codeSent ? '$_countdown 秒' : '发送验证码',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 注册按钮
                  FilledButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('注册', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // 用户协议
                  Text(
                    '注册即表示您同意我们的服务条款和隐私政策',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
