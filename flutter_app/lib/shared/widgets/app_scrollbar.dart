import 'package:flutter/material.dart';

class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    super.key,
    required this.builder,
    this.thumbVisibility = false,
  });

  final Widget Function(BuildContext context, ScrollController controller)
      builder;
  final bool thumbVisibility;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: widget.thumbVisibility,
      child: widget.builder(context, _controller),
    );
  }
}
