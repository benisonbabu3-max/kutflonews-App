import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../utils/theme.dart';

class SwipeCardStack extends StatefulWidget {
  final List<Article> articles;
  final VoidCallback? onRefresh;
  final Function(Article article, bool saved)? onSwiped;

  const SwipeCardStack({
    super.key,
    required this.articles,
    this.onRefresh,
    this.onSwiped,
  });

  @override
  State<SwipeCardStack> createState() => _SwipeCardStackState();
}

class _SwipeCardStackState extends State<SwipeCardStack>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _snapController;
  late AnimationController _flyController;
  Offset _flyTarget = Offset.zero;
  bool _isFlying = false;

  static const _swipeThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _flyController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _flyController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentIndex =
              (_currentIndex + 1).clamp(0, widget.articles.length);
          _dragOffset = Offset.zero;
          _isFlying = false;
          _flyController.reset();
        });
      }
    });
  }

  @override
  void didUpdateWidget(SwipeCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articles != widget.articles) {
      setState(() {
        _currentIndex = 0;
        _dragOffset = Offset.zero;
        _isFlying = false;
      });
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d) {
    if (_isFlying) return;
    setState(() {
      _isDragging = true;
      _snapController.stop();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isFlying) return;
    setState(() => _dragOffset += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isFlying) return;
    _isDragging = false;
    final dx = _dragOffset.dx;
    if (dx.abs() >= _swipeThreshold) {
      final saved = dx < 0; // left = save, right = skip
      final article = widget.articles[_currentIndex];
      _flyAway(dx < 0 ? -1 : 1);
      widget.onSwiped?.call(article, saved);
    } else {
      // Spring snap back
      final startOffset = _dragOffset;
      final anim = Tween<Offset>(begin: startOffset, end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _snapController, curve: Curves.elasticOut));
      anim.addListener(() {
        if (mounted) setState(() => _dragOffset = anim.value);
      });
      _snapController.forward(from: 0);
    }
  }

  void _flyAway(int direction) {
    final startOffset = _dragOffset;
    _flyTarget =
        Offset(direction * 600, _dragOffset.dy - 60);
    final anim =
        Tween<Offset>(begin: startOffset, end: _flyTarget).animate(
            CurvedAnimation(parent: _flyController, curve: Curves.easeIn));
    anim.addListener(() {
      if (mounted) setState(() => _dragOffset = anim.value);
    });
    setState(() => _isFlying = true);
    _flyController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) return const SizedBox(height: 236);

    final remaining = widget.articles.length - _currentIndex;
    if (remaining <= 0) return _buildAllDone();

    return SizedBox(
      height: 236,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_currentIndex + 2 < widget.articles.length)
            _buildBackCard(depth: 2),
          if (_currentIndex + 1 < widget.articles.length)
            _buildBackCard(depth: 1),
          _buildTopCard(),
        ],
      ),
    );
  }

  Widget _buildBackCard({required int depth}) {
    final scale = 1.0 - depth * 0.04;
    final ty = depth * 10.0;
    return Positioned.fill(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(0.0, ty)
          ..scale(scale),
        child: IgnorePointer(
          child: _CardFace(
              article: widget.articles[_currentIndex + depth],
              swipeProgress: 0),
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    final article = widget.articles[_currentIndex];
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy * 0.28;
    final angle = dx * 0.0011;
    final progress = (dx.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final isSaving = dx < -20;
    final isSkipping = dx > 20;

    return Positioned.fill(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(dx, dy)
            ..rotateZ(angle),
          child: Stack(children: [
            _CardFace(article: article, swipeProgress: progress),
            // SAVE label — swipe left
            if (isSaving)
              Positioned(
                right: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        border: Border.all(
                            color: AppColors.success, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('SAVE 🔖',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                              fontFamily: 'Inter')),
                    ),
                  ),
                ),
              ),
            // SKIP label — swipe right
            if (isSkipping)
              Positioned(
                left: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: progress,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF0EE),
                        border: Border.all(
                            color: AppColors.accentDark, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('SKIP',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentDark,
                              fontFamily: 'Inter')),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAllDone() {
    return SizedBox(
      height: 236,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border:
              Border.all(color: AppColors.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📡',
                  style: TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              const Text('All caught up!',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter')),
              const SizedBox(height: 4),
              const Text('Pull to refresh for new signals',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontFamily: 'Inter')),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: widget.onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.nearBlack,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Refresh feed',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.base,
                          fontFamily: 'Inter')),
                ),
              ),
            ]),
      ),
    );
  }
}

// ─── Card face ──────────────────────────────────────────────────────────────

class _CardFace extends StatelessWidget {
  final Article article;
  final double swipeProgress;

  const _CardFace(
      {required this.article, required this.swipeProgress});

  bool get _isDark =>
      article.type != ArticleType.productBlog;

  Color get _textColor =>
      _isDark ? Colors.white : AppColors.nearBlack;

  Color get _eyeColor => _isDark
      ? Colors.white.withOpacity(0.70)
      : AppColors.nearBlack.withOpacity(0.50);

  Color get _summaryBg => _isDark
      ? Colors.black.withOpacity(0.18)
      : Colors.black.withOpacity(0.07);

  Color get _summaryText =>
      _isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF3A2A14);

  Color get _btnBg =>
      _isDark ? AppColors.base : AppColors.nearBlack;

  Color get _btnText =>
      _isDark ? AppColors.nearBlack : AppColors.base;

  Future<void> _open() async {
    final uri = Uri.tryParse(article.url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: article.type.cardBg,
        border: Border.all(
            color: article.type.cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Stack(children: [
        // Ghost number
        Positioned(
          top: 8,
          right: 12,
          child: Text(
            '0${(article.estimatedMinutes / 3).ceil().clamp(1, 9)}',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color:
                  (_isDark ? Colors.white : Colors.black)
                      .withOpacity(0.07),
              fontFamily: 'Inter',
              height: 1,
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section
              Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Eyebrow
                    Row(children: [
                      Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: _eyeColor,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${article.type.label.toUpperCase()} · ${article.estimatedMinutes} MIN',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _eyeColor,
                              letterSpacing: .07,
                              fontFamily: 'Inter'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 7),
                    // Headline
                    Text(
                      article.title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                          height: 1.28,
                          letterSpacing: -.2,
                          fontFamily: 'Inter'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 9),
                    // Summary box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                          color: _summaryBg,
                          borderRadius:
                              BorderRadius.circular(9)),
                      child: Text(
                        article.summary.isNotEmpty
                            ? article.summary
                            : article.whyItMatters,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _summaryText,
                            height: 1.5,
                            fontFamily: 'Inter'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
              // Footer
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        article.source,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _eyeColor,
                            fontFamily: 'Inter'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _open,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: _btnBg,
                            borderRadius:
                                BorderRadius.circular(20)),
                        child: Text('Read full →',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _btnText,
                                fontFamily: 'Inter')),
                      ),
                    ),
                  ]),
            ],
          ),
        ),
      ]),
    );
  }
}
