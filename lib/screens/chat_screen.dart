import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  const ChatScreen({super.key, this.conversationId});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatService _chat;
  List<Conversation> _conversations = [];
  Conversation? _active;
  List<Message> _messages = [];
  bool _loadingConvs = true;
  String? _convoLoadError;
  bool _loadingMsgs = false;
  String? _typingConvoId;
  /// Display name from socket payload when provided; otherwise use other participant.
  String? _typingPeerName;
  bool _socketConnected = false;
  bool _socketConnecting = true;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _typingTimer;
  Timer? _refreshTimer;
  DateTime? _lastTypingEmit;

  @override
  void initState() {
    super.initState();
    _chat = ChatService();
    _loadConversations();
    _initSocket();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _syncConversations());
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _refreshTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _chat.disposeSocket();
    super.dispose();
  }

  Future<void> _syncConversations() async {
    try {
      final convs = await _chat.getConversations();
      if (!mounted) return;
      setState(() { _conversations = convs; _convoLoadError = null; });
      for (final c in convs) {
        _chat.joinRoom(c.id);
      }
    } catch (_) {}
  }

  Future<void> _initSocket() async {
    setState(() => _socketConnecting = true);
    await _chat.initSocket(
      onMessage: (msg) {
        if (!mounted) return;

        final isActiveConvo = _active != null && msg.conversationId == _active!.id;
        final knownConvo = _conversations.any((c) => c.id == msg.conversationId);

        setState(() {
          _socketConnected = true;
          _socketConnecting = false;

          if (isActiveConvo) {
            final exists = _messages.any((m) => m.id == msg.id || (m.id.startsWith('opt-') && m.sender?.id == msg.sender?.id && m.content == msg.content));
            if (!exists) {
              _messages = [..._messages, msg];
            } else {
              // Replace optimistic with real
              _messages = _messages.map((m) => (m.id.startsWith('opt-') && m.sender?.id == msg.sender?.id && m.content == msg.content) ? msg : m).toList();
            }
          }

          if (knownConvo) {
            _conversations = _conversations.map((c) {
              if (c.id == msg.conversationId) {
                return Conversation(
                  id: c.id,
                  participants: c.participants,
                  job: c.job,
                  lastMessage: msg,
                  unreadCount: isActiveConvo ? 0 : c.unreadCount + 1,
                  createdAt: c.createdAt,
                  updatedAt: msg.createdAt,
                );
              }
              return c;
            }).toList();
          }

          _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });

        if (!knownConvo) {
          _syncConversations();
        }

        if (isActiveConvo) {
          _scrollDown();
          _chat.markRead(_active!.id);
        }
      },
      onConversationChanged: () {
        // Ensure conversation list stays in sync when server emits conversation/new/hidden/deleted/read.
        _syncConversations();
      },
      onTyping: (userId, convoId, userName) {
        final me = ref.read(authProvider).user?.id;
        if (userId == me || !mounted) return;
        setState(() {
          _typingConvoId = convoId;
          _typingPeerName =
              userName != null && userName.trim().isNotEmpty ? userName.trim() : null;
          _socketConnected = true;
          _socketConnecting = false;
        });
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingConvoId = null;
              _typingPeerName = null;
            });
          }
        });
      },
      onConnect: () {
        if (!mounted) return;
        setState(() { _socketConnected = true; _socketConnecting = false; });
        for (final c in _conversations) {
          _chat.joinRoom(c.id);
        }
      },
      onDisconnect: () {
        if (!mounted) return;
        setState(() { _socketConnected = false; });
      },
    );
    if (mounted) setState(() { _socketConnected = _chat.isSocketConnected; _socketConnecting = false; });
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await _chat.getConversations();
      if (!mounted) return;
      setState(() { _conversations = convs; _loadingConvs = false; _convoLoadError = null; });
      for (final c in convs) {
        _chat.joinRoom(c.id);
      }
      if (widget.conversationId != null) {
        final conv = convs.where((c) => c.id == widget.conversationId).firstOrNull;
        if (conv != null) {
          _selectConversation(conv);
        } else {
          _loadConversationDirectly(widget.conversationId!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConvs = false;
        _convoLoadError = 'Failed to load chats. Check connection / login and try again.';
      });
      if (widget.conversationId != null) {
        _loadConversationDirectly(widget.conversationId!);
      }
    }
  }

  Future<void> _loadConversationDirectly(String convoId) async {
    try {
      setState(() { _loadingMsgs = true; });
      final msgs = await _chat.getMessages(convoId);
      if (!mounted) return;

      final me = ref.read(authProvider).user;
      User? otherUser;
      for (final msg in msgs) {
        if (msg.sender != null && msg.sender!.id != me?.id) {
          otherUser = msg.sender;
          break;
        }
      }

      final directConvo = Conversation(
        id: convoId,
        participants: [if (me != null) me, if (otherUser != null) otherUser],
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        lastMessage: msgs.isNotEmpty ? msgs.last : null,
      );

      _chat.joinRoom(convoId);
      setState(() {
        _active = directConvo;
        _messages = msgs;
        _loadingMsgs = false;
        if (!_conversations.any((c) => c.id == convoId)) {
          _conversations = [directConvo, ..._conversations];
        }
      });
      _scrollDown();
      await _chat.markRead(convoId);
    } catch (_) {
      if (mounted) setState(() => _loadingMsgs = false);
    }
  }

  Future<void> _selectConversation(Conversation conv) async {
    setState(() { _active = conv; _loadingMsgs = true; _messages = []; });
    _chat.joinRoom(conv.id);
    try {
      final msgs = await _chat.getMessages(conv.id);
      if (mounted) setState(() { _messages = msgs; _loadingMsgs = false; });
      _scrollDown();
      await _chat.markRead(conv.id);
      if (mounted) {
        setState(() {
          _conversations = _conversations.map((c) => c.id == conv.id
              ? Conversation(id: c.id, participants: c.participants, job: c.job,
                  lastMessage: c.lastMessage, unreadCount: 0, createdAt: c.createdAt, updatedAt: c.updatedAt)
              : c).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMsgs = false);
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty || _active == null) return;
    _inputCtrl.clear();
    _lastTypingEmit = null;
    final me = ref.read(authProvider).user!;

    final optimistic = Message(
      id: 'opt-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _active!.id,
      sender: me,
      content: content,
      read: false,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _messages = [..._messages, optimistic];
      _conversations = _conversations.map((c) {
        if (c.id == _active!.id) {
          return Conversation(
            id: c.id, participants: c.participants, job: c.job,
            lastMessage: optimistic, unreadCount: 0,
            createdAt: c.createdAt, updatedAt: optimistic.createdAt,
          );
        }
        return c;
      }).toList();
    });
    _scrollDown();

    try {
      // Use REST as the single source of truth for send; backend broadcasts to sockets.
      final real = await _chat.sendMessageRest(_active!.id, content);
      if (!mounted) return;
      setState(() => _messages = _messages.map((m) => m.id == optimistic.id ? real : m).toList());
    } catch (e) {
      if (!mounted) return;
      // If the socket already delivered and replaced the optimistic message,
      // the send actually succeeded — suppress the error.
      final stillPending = _messages.any((m) => m.id == optimistic.id);
      if (!stillPending) return;
      debugPrint('SEND_ERR: ${_chat.extractError(e)}');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Failed to send. Check your connection.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _handleTyping() {
    final me = ref.read(authProvider).user?.id;
    if (_active == null || me == null || !_chat.isSocketConnected) return;
    final now = DateTime.now();
    if (_lastTypingEmit == null ||
        now.difference(_lastTypingEmit!) >= const Duration(milliseconds: 900)) {
      _lastTypingEmit = now;
      _chat.emitTyping(_active!.id, me);
    }
  }

  bool get _isTypingInActive => _typingConvoId != null && _typingConvoId == _active?.id;

  String? _typingDisplayLabel(User? me) {
    if (!_isTypingInActive) return null;
    if (_typingPeerName != null) return _typingPeerName;
    return _active?.otherParticipant(me?.id ?? '')?.name;
  }

  Widget _buildHeaderSubtitle(User? me) {
    if (_active?.job != null) {
      return Text(
        _active!.job!.title,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  void _goBack() {
    if (widget.conversationId != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/chat');
      }
    } else {
      setState(() { _active = null; _messages = []; });
    }
  }

  Future<void> _deleteConversation() async {
    if (_active == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete conversation?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final deletedId = _active!.id;
        await _chat.deleteConversation(deletedId);
        _chat.leaveRoom(deletedId);
        if (mounted) setState(() { _conversations = _conversations.where((c) => c.id != deletedId).toList(); _active = null; _messages = []; });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: widget.conversationId != null || _active == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _active != null) {
          setState(() { _active = null; _messages = []; });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _active != null && isNarrow
            ? AppBar(
                backgroundColor: Colors.white,
                titleSpacing: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: _goBack,
                ),
                title: Row(children: [
                  AvatarCircle(_active!.otherParticipant(me?.id ?? '')?.initials ?? '?', size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_active!.otherParticipant(me?.id ?? '')?.name ?? '',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      _buildHeaderSubtitle(me),
                    ]),
                  ),
                ]),
                actions: [
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted), onPressed: _deleteConversation),
                ],
              )
            : AppBar(
                backgroundColor: AppColors.background,
                title: const Text('Messages'),
                automaticallyImplyLeading: false,
              ),
        body: Column(
          children: [
            ConnectionStatusBar(connected: _socketConnected, connecting: _socketConnecting),
            Expanded(child: isNarrow ? _buildNarrowBody(me) : _buildWideBody(me)),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrowBody(dynamic me) {
    if (_active != null) return _buildMessagePane(me, showHeader: false);
    return _buildConversationList(me);
  }

  Widget _buildWideBody(dynamic me) {
    return Row(
      children: [
        SizedBox(width: 300, child: _buildConversationList(me)),
        Expanded(
          child: _active == null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.creamDark, shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select a conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                  ]),
                )
              : _buildMessagePane(me, showHeader: true),
        ),
      ],
    );
  }

  Widget _buildConversationList(dynamic me) {
    final isClient = me?.role == 'client';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: _loadingConvs
          ? const Center(child: CircularProgressIndicator())
          : _convoLoadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.wifi_off_rounded, size: 34, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(_convoLoadError!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _loadingConvs = true);
                          _loadConversations();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ]),
                  ),
                )
          : _conversations.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.creamDark, shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    const Text('No conversations yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                    const SizedBox(height: 6),
                    Text(
                      isClient
                          ? 'Conversations will appear when applicants message you'
                          : 'Apply to a job to start a conversation',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    if (isClient)
                      ElevatedButton.icon(
                        onPressed: () => context.go('/dashboard'),
                        icon: const Icon(Icons.dashboard_rounded, size: 18),
                        label: const Text('Go to Dashboard'),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => context.go('/jobs'),
                        icon: const Icon(Icons.work_outline_rounded, size: 18),
                        label: const Text('Browse Jobs'),
                      ),
                    const SizedBox(height: 16),
                  ]),
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final conv = _conversations[i];
                    final other = conv.otherParticipant(me?.id ?? '');
                    final isActive = _active?.id == conv.id;
                    return _ConversationTile(
                      conv: conv,
                      otherName: other?.name ?? '',
                      otherInitials: other?.initials ?? '?',
                      isActive: isActive,
                      onTap: () => _selectConversation(conv),
                    );
                  },
                ),
    );
  }

  Widget _buildMessagePane(dynamic me, {required bool showHeader}) {
    return Column(
      children: [
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              AvatarCircle(_active!.otherParticipant(me?.id ?? '')?.initials ?? '?', size: 38),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_active!.otherParticipant(me?.id ?? '')?.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                _buildHeaderSubtitle(me),
              ])),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                onPressed: _deleteConversation,
              ),
            ]),
          ),
        Expanded(
          child: _loadingMsgs
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.creamDark, shape: BoxShape.circle),
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 32, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        const Text('No messages yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textBody)),
                        const SizedBox(height: 4),
                        const Text('Send a message to start the conversation', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ]),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe = msg.sender?.id == me?.id;
                        final showDate = i == 0 || _isDifferentDay(_messages[i - 1].createdAt, msg.createdAt);
                        return Column(children: [
                          if (showDate) _DateDivider(msg.createdAt),
                          _MessageBubble(msg: msg, isMe: isMe),
                        ]);
                      },
                    ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final label = _typingDisplayLabel(me);
                      if (label == null || label.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _TypingComposerLine(displayName: label),
                      );
                    },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: TextField(
                            controller: _inputCtrl,
                            onChanged: (_) => _handleTyping(),
                            onSubmitted: (_) => _send(),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            cursorColor: AppColors.navy,
                            cursorRadius: const Radius.circular(2),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textBody,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message…',
                              hintStyle: TextStyle(
                                color: AppColors.textMuted.withValues(alpha: 0.7),
                                fontSize: 15,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF4F4F6),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder(
                        valueListenable: _inputCtrl,
                        builder: (_, v, __) {
                          final hasText = v.text.trim().isNotEmpty;
                          return AnimatedOpacity(
                            opacity: hasText ? 1.0 : 0.35,
                            duration: const Duration(milliseconds: 180),
                            child: GestureDetector(
                              onTap: hasText ? _send : null,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.navy,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isDifferentDay(String a, String b) {
    try {
      final da = DateTime.parse(a).toLocal();
      final db = DateTime.parse(b).toLocal();
      return da.day != db.day || da.month != db.month || da.year != db.year;
    } catch (_) { return false; }
  }
}

/// Subtle “… Name is typing…” above the composer (matches common chat UX).
class _TypingComposerLine extends StatefulWidget {
  final String displayName;
  const _TypingComposerLine({required this.displayName});

  @override
  State<_TypingComposerLine> createState() => _TypingComposerLineState();
}

class _TypingComposerLineState extends State<_TypingComposerLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dotColor = AppColors.textMuted;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final phase = _ctrl.value * 3;
        return Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final wave = ((phase - i).abs() < 0.4) ? 1.0 : 0.35;
                return Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 3 : 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.25 + 0.55 * wave),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
            Expanded(
              child: Text(
                '${widget.displayName} is typing…',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Conversation Tile ─────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final Conversation conv;
  final String otherName, otherInitials;
  final bool isActive;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.otherName,
    required this.otherInitials,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isActive ? AppColors.creamDark : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Stack(children: [
            AvatarCircle(otherInitials, size: 44),
            if (conv.unreadCount > 0)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                  alignment: Alignment.center,
                  child: Text('${conv.unreadCount}',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(otherName,
                      style: TextStyle(fontWeight: conv.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(_timeAgo(conv.updatedAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 2),
              if (conv.job != null)
                Text(conv.job!.title,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              if (conv.lastMessage != null)
                Text(conv.lastMessage!.content,
                    style: TextStyle(
                        fontSize: 12,
                        color: conv.unreadCount > 0 ? AppColors.textBody : AppColors.textMuted,
                        fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
            ]),
          ),
        ]),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) { return ''; }
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Message msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isOptimistic = msg.id.startsWith('opt-');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(msg.sender?.name ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            ),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                AvatarCircle(msg.sender?.initials ?? '?', size: 28),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.navy : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    boxShadow: isMe ? [] : AppColors.cardShadowLight,
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppColors.textBody,
                        height: 1.45),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Icon(
                  isOptimistic ? Icons.access_time_rounded : Icons.done_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 3, left: isMe ? 0 : 42, right: 2),
            child: Text(_formatTime(msg.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
      final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
      final m = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      if (isToday) return '$h:$m $ampm';
      return '${d.month}/${d.day} $h:$m $ampm';
    } catch (_) { return ''; }
  }
}

// ── Date Divider ──────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String iso;
  const _DateDivider(this.iso);

  @override
  Widget build(BuildContext context) {
    String label = '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(d.year, d.month, d.day);
      final diff = today.difference(msgDay).inDays;
      if (diff == 0) {
        label = 'Today';
      } else if (diff == 1) {
        label = 'Yesterday';
      } else {
        label = '${d.month}/${d.day}/${d.year}';
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

