import 'package:flutter/material.dart';
import 'package:mikan_player/ui/widgets/anime_card.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterRow(context, 'Type', [
                  'All',
                  'TV',
                  'Web',
                  'OVA',
                  'Movie',
                ]),
                _buildFilterRow(context, 'Source', [
                  'All',
                  'Original',
                  'Manga',
                  'Novel',
                  'Game',
                ]),
                _buildFilterRow(context, 'Genre', [
                  'All',
                  'Sci-Fi',
                  'Comedy',
                  'Action',
                  'Slice of Life',
                ]),
                _buildFilterRow(context, 'Year', [
                  '2026',
                  '2025',
                  '2024',
                  '2023',
                ]),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return AnimeCard(
                title: 'Filtered Anime Result $index',
                tag: 'TV',
              );
            }, childCount: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    String label,
    List<String> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((option) {
                  final isSelected = option == options.first;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (bool value) {},
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : null,
                      ),
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
