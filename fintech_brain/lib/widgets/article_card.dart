import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../services/ollama_service.dart';
import '../utils/theme.dart';

// ─── DESIGN TOKEN — single source of truth for button radius ───────────────
const _kBtnRadius = 10.0;   // all action buttons: 10px
const _kCardRadius = 18.0;  // all cards: 18px
// ───────────────────────────────────────────────────────────────────────────

class ArticleCard extends StatefulWidget {
  final Article article;
  final VoidCallback onRead;
  final VoidCallback onSave;
  final bool showReviewBadge;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onRead,
    required this.onSave,
    this.showReviewBadge = false,
  });

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  bool _chatOpen = false;

  Article get _a => widget.article;

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(_a.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _a.isRead ? 0.65 : 1.0,
      duration: const Duration(milliseconds: 280),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          borderRadius: BorderRadius.circular(_kCardRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildTop(),
            _buildBody(),
            if (_chatOpen) _AiChatPanel(article: _a),
          ]),
        ),
      ),
    );
  }

  Widget _buildTop() {
    final isDark = _a.type != ArticleType.productBlog;
    final textColor = isDark ? Colors.white : AppColors.nearBlack;
    final eyeColor =
        isDark ? Colors.white.withOpacity(0.7) : AppColors.nearBlack.withOpacity(0.5);

    return Container(
      decoration: BoxDecoration(
        color: _a.type.cardBg,
        border: Border(
            bottom: BorderSide(color: _a.type.cardBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Stack(children: [
        // Ghost number
        Positioned(
          top: 0,
          right: 4,
          child: Text(
            '0${(_a.estimatedMinutes / 3).ceil().clamp(1, 9)}',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.07),
              fontFamily: 'Inter',
              height: 1,
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Eyebrow row
          Row(children: [
            Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: eyeColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '${_a.type.label.toUpperCase()} · ${_a.estimatedMinutes} MIN',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: eyeColor,
                  letterSpacing: .08,
                  fontFamily: 'Inter'),
            ),
            if (widget.showReviewBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withOpacity(.85),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('↻ Review',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Inter')),
              ),
            ],
          ]),
          const SizedBox(height: 7),
          // Headline
          Text(
            _a.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.3,
              letterSpacing: -.15,
              fontFamily: 'Inter',
            ),
          ),
          // 60-word summary on the card top
          if (_a.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.black).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _a.summary,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withOpacity(0.88)
                      : AppColors.nearBlack.withOpacity(0.80),
                  height: 1.55,
                  fontFamily: 'Inter',
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLighter, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Why it matters callout
        if (_a.whyItMatters.isNotEmpty) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: const BoxDecoration(
              color: AppColors.base,
              border: Border(
                  left: BorderSide(color: AppColors.accent, width: 2.5)),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, height: 1.55, fontFamily: 'Inter'),
                children: [
                  const TextSpan(
                    text: 'Why this matters: ',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  TextSpan(
                    text: _a.whyItMatters,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Action buttons — all radius=10, consistent
        Row(children: [
          Expanded(
            child: _ActionBtn(
              label: _a.isRead ? '✓ Done' : 'Mark done',
              bg: _a.isRead ? AppColors.success : AppColors.nearBlack,
              fg: Colors.white,
              onTap: widget.onRead,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionBtn(
              label: _a.isSaved ? 'Saved' : 'Save',
              bg: _a.isSaved ? AppColors.product : AppColors.nearBlack,
              fg: Colors.white,
              onTap: widget.onSave,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ActionBtn(
              label: 'Read →',
              bg: AppColors.nearBlack,
              fg: AppColors.base,
              onTap: _openUrl,
            ),
          ),
          const SizedBox(width: 6),
          // Ask AI button
          _ActionBtn(
            label: '✦ AI',
            bg: _chatOpen ? AppColors.accent : AppColors.nearBlack,
            fg: Colors.white,
            onTap: () => setState(() => _chatOpen = !_chatOpen),
            minWidth: 44,
          ),
        ]),
      ]),
    );
  }
}

// ─── AI Inline Chat Panel ────────────────────────────────────────────────────

class _AiChatPanel extends StatefulWidget {
  final Article article;
  const _AiChatPanel({required this.article});

  @override
  State<_AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<_AiChatPanel> {
  final _ai = OllamaService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _loading = false;

  static const _suggestions = [
    'Explain this simply',
    'How does this affect my career?',
    'What should I do next?',
    'Give me a related example',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _loading) return;
    final q = text.trim();
    _ctrl.clear();
    setState(() {
      _msgs.add(_ChatMsg(role: 'user', content: q));
      _loading = true;
    });
    _scrollToBottom();

    final history = _msgs
        .take(_msgs.length - 1)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final answer = await _ai.askAboutArticle(
      articleId: widget.article.id,
      question: q,
      articleTitle: widget.article.title,
      articleSummary: widget.article.summary.isNotEmpty
          ? widget.article.summary
          : widget.article.whyItMatters,
      history: history,
    );

    if (!mounted) return;
    setState(() {
      _msgs.add(_ChatMsg(role: 'ai', content: answer.answer));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF0EDE6),
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 13, color: Colors.white),
            ),
            const SizedBox(width: 7),
            const Text('Ask AI about this article',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter')),
          ]),
        ),

        // Quick suggestions (only when no messages)
        if (_msgs.isEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(_suggestions[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                        color: AppColors.borderLight, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_suggestions[i],
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter')),
                ),
              ),
            ),
          ),
        ],

        // Messages
        if (_msgs.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              shrinkWrap: true,
              itemCount: _msgs.length,
              itemBuilder: (_, i) => _buildMsg(_msgs[i]),
            ),
          ),

        // Loading indicator
        if (_loading)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
              SizedBox(width: 8),
              Text('AI is thinking...',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFamily: 'Inter')),
            ]),
          ),

        // Input row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                      color: AppColors.borderLight, width: 1.5),
                  borderRadius: BorderRadius.circular(_kBtnRadius),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter'),
                  decoration: const InputDecoration(
                    hintText: 'Ask anything about this article...',
                    hintStyle: TextStyle(
                        color: Color(0xFFB0ACA4),
                        fontSize: 12,
                        fontFamily: 'Inter'),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    isDense: true,
                  ),
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            const SizedBox(width: 7),
            GestureDetector(
              onTap: () => _send(_ctrl.text),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.nearBlack,
                  borderRadius: BorderRadius.circular(_kBtnRadius),
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    size: 16, color: AppColors.base),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMsg(_ChatMsg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 7, top: 1),
              decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(5)),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 12, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? AppColors.nearBlack : AppColors.surface,
                border: isUser
                    ? null
                    : Border.all(color: AppColors.borderLight, width: 1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 10 : 3),
                  topRight: const Radius.circular(10),
                  bottomLeft: const Radius.circular(10),
                  bottomRight: Radius.circular(isUser ? 3 : 10),
                ),
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isUser ? AppColors.base : AppColors.textPrimary,
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String role; // 'user' or 'ai'
  final String content;
  const _ChatMsg({required this.role, required this.content});
}

// ─── Action button — consistent radius across whole app ─────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback? onTap;
  final double? minWidth;

  const _ActionBtn({
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: minWidth != null
            ? BoxConstraints(minWidth: minWidth!)
            : null,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_kBtnRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
            fontFamily: 'Inter',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
