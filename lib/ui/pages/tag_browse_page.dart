import 'package:flutter/material.dart';
import 'package:mikan_player/ui/pages/search_page.dart';

class TagBrowsePage extends StatelessWidget {
  final String tagName;

  const TagBrowsePage({super.key, required this.tagName});

  @override
  Widget build(BuildContext context) {
    return SearchPage(initialTag: tagName);
  }
}
