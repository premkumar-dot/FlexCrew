import 'package:flutter/material.dart';

class AvatarWithName extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final double radius;
  final VoidCallback? onTap;
  final TextStyle? textStyle;

  const AvatarWithName({
    Key? key,
    this.imageUrl,
    this.displayName,
    this.radius = 40,
    this.onTap,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = (displayName ?? '').trim();
    final avatarSize = radius * 2;
    final effectiveTextStyle = textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: radius * 0.4);

    Widget avatarChild;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          imageUrl!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _initialsFallback(name, radius, context),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: avatarSize,
              height: avatarSize,
              color: Colors.grey.shade200,
              child: Center(
                child: SizedBox(
                  width: radius * 0.7,
                  height: radius * 0.7,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      avatarChild = _initialsFallback(name, radius, context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: avatarChild,
          ),
        ),
        const SizedBox(height: 8),
        if (name.isNotEmpty)
          SizedBox(
            width: avatarSize + 8,
            child: Text(
              name,
              style: effectiveTextStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _initialsFallback(String name, double radius, BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : '';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(fontSize: radius * 0.6, color: Colors.grey.shade700),
        ),
      ),
    );
  }
}
