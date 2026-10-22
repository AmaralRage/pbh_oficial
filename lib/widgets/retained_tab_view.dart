import 'package:flutter/material.dart';

/// Initializes a tab on its first visit and keeps its state until the account changes.
class RetainedTabView extends StatefulWidget {
  const RetainedTabView({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;
  @override
  State<RetainedTabView> createState() => _RetainedTabViewState();
}

class _RetainedTabViewState extends State<RetainedTabView> {
  final _visited = <int>{};
  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _visited.contains(i)
                ? widget.children[i]
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
