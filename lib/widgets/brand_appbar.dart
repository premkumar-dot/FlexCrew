import 'package:flutter/material.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String tagline;
  final double logoSize;

  const BrandAppBar({
    super.key,
    required this.title,
    required this.tagline,
    this.logoSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ClipOval(
              child: Image.asset(
                'assets/branding/logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                semanticLabel: 'App logo',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // App name
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                // Tagline (smaller)
                Text(
                  tagline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      // optional: other AppBar properties
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
