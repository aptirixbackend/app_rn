import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// A row of [length] single-digit boxes with auto-advance and backspace-to-back.
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.error = false,
    this.resetToken = 0,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  /// When true, the boxes are outlined in red to signal an invalid code.
  final bool error;

  /// Change this value to clear all boxes (e.g. after a wrong code).
  final int resetToken;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());

    for (var i = 0; i < widget.length; i++) {
      final idx = i;
      _nodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[idx].text.isEmpty &&
            idx > 0) {
          _controllers[idx - 1].clear();
          _nodes[idx - 1].requestFocus();
          setState(() {});
          widget.onChanged(_code);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void didUpdateWidget(OtpInputField old) {
    super.didUpdateWidget(old);
    // A new resetToken means the parent wants the boxes cleared (wrong code).
    if (old.resetToken != widget.resetToken) {
      for (final c in _controllers) {
        c.clear();
      }
      _nodes.first.requestFocus();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _handleChanged(int i, String value) {
    if (value.length > 1) {
      // Pasted / autofilled code — distribute across the boxes.
      final chars = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var j = 0; j < widget.length; j++) {
        _controllers[j].text = j < chars.length ? chars[j] : '';
      }
      final next = (chars.length).clamp(0, widget.length - 1);
      _nodes[next].requestFocus();
    } else if (value.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    }

    setState(() {});
    widget.onChanged(_code);
    if (_code.length == widget.length && !_code.contains(RegExp(r'\s'))) {
      final full = _code;
      if (full.length == widget.length) widget.onCompleted?.call(full);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        final filled = _controllers[i].text.isNotEmpty;
        const errorColor = Color(0xFFE23D3D);
        return SizedBox(
          width: 48,
          height: 56,
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.error
                      ? errorColor
                      : (filled ? AppColors.primary : AppColors.boxBorder),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: widget.error ? errorColor : AppColors.primary,
                    width: 1.6),
              ),
            ),
            onChanged: (v) => _handleChanged(i, v),
          ),
        );
      }),
    );
  }
}
