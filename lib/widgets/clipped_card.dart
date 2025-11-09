// lib/widgets/clipped_card.dart
// Хэрэглэхэд хялбар, clipBehavior-тэй Card widget

import 'package:flutter/material.dart';

class ClippedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final ShapeBorder? shape;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  const ClippedCard({
    Key? key,
    required this.child,
    this.margin,
    this.color,
    this.elevation,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin,
      color: color,
      elevation: elevation ?? 2,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

// ============================================
// АШИГЛАХ ЖИШЭЭ
// ============================================

// Example 1: Энгийн card
/*
ClippedCard(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Миний агуулга'),
  ),
)
*/

// Example 2: Зургатай card
/*
ClippedCard(
  child: Column(
    children: [
      Image.network('https://...'),
      Padding(
        padding: EdgeInsets.all(16),
        child: Text('Гарчиг'),
      ),
    ],
  ),
)
*/

// Example 3: Товчлуурын үүрэгтэй card
/*
ClippedCard(
  onTap: () {
    print('Card дарагдлаа');
  },
  child: ListTile(
    leading: Icon(Icons.person),
    title: Text('Хэрэглэгч'),
    subtitle: Text('user@example.com'),
  ),
)
*/

// Example 4: Өөрчлөгдсөн elevation ба өнгө
/*
ClippedCard(
  elevation: 4,
  color: Colors.blue.shade50,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Тусгай card'),
  ),
)
*/

// Example 5: Өөр clipBehavior
/*
ClippedCard(
  clipBehavior: Clip.hardEdge,
  child: // your content
)
*/