import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AvatarWithName extends StatefulWidget {
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
  State<AvatarWithName> createState() => _AvatarWithNameState();
}

class _AvatarWithNameState extends State<AvatarWithName> {
  String? _resolvedUrl;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _prepareUrl();
  }

  @override
  void didUpdateWidget(covariant AvatarWithName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _prepareUrl();
    }
  }

  Future<void> _prepareUrl() async {
    final raw = widget.imageUrl;
    if (raw == null || raw.isEmpty) {
      setState(() {
        _resolvedUrl = null;
        _resolving = false;
      });
      return;
    }

    // If already an http/https/data: URL we can use directly
    if (raw.startsWith('http') || raw.startsWith('data:')) {
      setState(() {
        _resolvedUrl = raw;
        _resolving = false;
      });
      return;
    }

    // If gs:// Storage URI, attempt to resolve to a download URL
    if (raw.startsWith('gs://')) {
      setState(() => _resolving = true);
      try {
        final ref = FirebaseStorage.instance.refFromURL(raw);
        final url = await ref.getDownloadURL();
        if (mounted) {
          setState(() {
            _resolvedUrl = url;
            _resolving = false;
          });
        }
        return;
      } catch (e, st) {
        debugPrint('AvatarWithName: failed to resolve gs:// -> $e\n$st');
        if (mounted) setState(() {
          _resolvedUrl = null;
          _resolving = false;
        });
        return;
      }
    }

    // Fallback: treat as string but the image loader may fail and show initials
    setState(() {
      _resolvedUrl = raw;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.displayName ?? '').trim();
    final avatarSize = widget.radius * 2;
    final effectiveTextStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: widget.radius * 0.4);

    Widget avatarChild;
    final imageToUse = _resolvedUrl;
    if (imageToUse != null && imageToUse.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          imageToUse,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          // IMPROVEMENT: Better error handling with initials fallback
          errorBuilder: (ctx, err, stack) {
            debugPrint('AvatarWithName: Image.network error for $imageToUse -> $err');
            return _initialsFallback(name, widget.radius, context);
          },
          // IMPROVEMENT: Show loading progress
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: widget.radius * 0.7,
                  height: widget.radius * 0.7,
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
      // If resolving is in progress, show a subtle placeholder spinner; otherwise initials fallback
      avatarChild = _resolving
          ? Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
              child: Center(
                child: SizedBox(
                  width: widget.radius * 0.6,
                  height: widget.radius * 0.6,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _initialsFallback(name, widget.radius, context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
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

  // IMPROVEMENT: Consistent initials fallback with better styling
  Widget _initialsFallback(String name, double radius, BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontSize: radius * 0.6,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
