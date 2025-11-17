import 'package:flutter/material.dart';
import 'theme_colors.dart';

class LikeHeart extends StatefulWidget {
  final bool isFavorite;
  final double size;
  final VoidCallback onToggle;

  const LikeHeart({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24,
  });

  @override
  State<LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<LikeHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _starsOpacity;

  // utilisé pour ne jouer les étoiles QUE lors du passage false -> true
  bool _lastFavorite = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: ThemeColors.textSecondary,
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _starsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.isFavorite) {
      _controller.value = 1.0;
      _lastFavorite = true;
    }
  }

  @override
  void didUpdateWidget(covariant LikeHeart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // transition de like
    if (!_lastFavorite && widget.isFavorite) {
      // false -> true : on joue l'animation complète (cœur + étoiles)
      _controller.forward(from: 0.0);
      _lastFavorite = true;
    } else if (_lastFavorite && !widget.isFavorite) {
      // true -> false : on enlève juste la couleur / échelle, sans étoiles
      _controller.reverse();
      _lastFavorite = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = _colorAnimation.value ?? ThemeColors.textSecondary;
        final scale = _scaleAnimation.value;

        final showStars =
            !_lastFavorite && widget.isFavorite || _controller.isAnimating;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // étoiles uniquement pendant l'anim de like
            if (showStars)
              Opacity(
                opacity: _starsOpacity.value,
                child: SizedBox(
                  width: widget.size * 2,
                  height: widget.size * 2,
                  child: _buildStars(color),
                ),
              ),
            // cœur
            Transform.scale(
              scale: scale,
              child: IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: widget.isFavorite ? Colors.red : color,
                  size: widget.size,
                ),
                padding: EdgeInsets.zero,
                splashRadius: widget.size,
                onPressed: widget.onToggle,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStars(Color color) {
    final starSize = widget.size * 0.35;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: widget.size * 0.3,
          child: Icon(
            Icons.star,
            size: starSize,
            color: color.withOpacity(0.9),
          ),
        ),
        Positioned(
          top: widget.size * 0.25,
          right: 0,
          child: Icon(
            Icons.star,
            size: starSize * 0.8,
            color: color.withOpacity(0.8),
          ),
        ),
        Positioned(
          bottom: 0,
          left: widget.size * 0.1,
          child: Icon(
            Icons.star,
            size: starSize * 0.7,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
