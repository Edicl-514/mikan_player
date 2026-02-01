import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class BangumiMaskText extends StatefulWidget {
  final String html;
  final TextStyle? textStyle;

  const BangumiMaskText({
    super.key,
    required this.html,
    this.textStyle,
  });

  @override
  State<BangumiMaskText> createState() => _BangumiMaskTextState();
}

class _BangumiMaskTextState extends State<BangumiMaskText> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _revealed = true),
      onExit: (_) => setState(() => _revealed = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _revealed = !_revealed;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: _revealed ? Colors.transparent : const Color(0xFF555555),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: const Color(0xFF555555),
              width: 1,
            ),
          ),
          child: HtmlWidget(
            widget.html,
            textStyle: (widget.textStyle ?? const TextStyle()).copyWith(
              color: _revealed ? null : const Color(0xFF555555),
            ),
          ),
        ),
      ),
    );
  }
}
