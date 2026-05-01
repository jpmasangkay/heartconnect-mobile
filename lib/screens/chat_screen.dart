import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
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
  bool _isSending = false;
  XFile? _selectedFile;
  /// IDs of messages confirmed via REST response — used to de-dup against socket echoes.
  final Set<String> _confirmedMessageIds = {};
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _typingTimer;
  DateTime? _lastTypingEmit;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _chat = ChatService.instance;
    _loadConversations();
    _initSocket();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _typingTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncConversations() async {
    try {
      final convs = await _chat.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _convoLoadError = null;
        // If the active conversation was deleted remotely (by the other party
        // or from another device), clear it so the message pane doesn't linger.
        if (_active != null && !convs.any((c) => c.id == _active!.id)) {
          _active = null;
          _messages = [];
          // Deep-linked route: navigate away since there is nothing to show.
          if (widget.conversationId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/chat');
              }
            });
          }
        }
      });
      for (final c in convs) {
        _chat.joinRoom(c.id);
      }
    } catch (_) {}
  }

  Future<void> _initSocket() async {
    setState(() => _socketConnecting = true);
    
    _chat.setupSocketListeners();

    _subs.add(_chat.onMessage.listen((msg) {
      if (!mounted) return;

      // Skip socket echoes for messages we already confirmed via REST response.
      if (_confirmedMessageIds.remove(msg.id)) return;

      final isActiveConvo = _active != null && msg.conversationId == _active!.id;
      final knownConvo = _conversations.any((c) => c.id == msg.conversationId);

      setState(() {
        _socketConnected = true;
        _socketConnecting = false;

        if (isActiveConvo) {
          final dupIdx = _messages.indexWhere((m) => m.id == msg.id);
          if (dupIdx >= 0) {
            // Exact duplicate — skip
          } else {
            // Try to match the oldest optimistic message from this sender with same content
            final optIdx = _messages.indexWhere((m) =>
                m.id.startsWith('opt-') &&
                m.sender?.id == msg.sender?.id);
            if (optIdx >= 0) {
              _messages = List.of(_messages)..[optIdx] = msg;
            } else {
              _messages = [..._messages, msg];
            }
          }
        }

        if (knownConvo) {
          final updated = List.of(_conversations);
          final idx = updated.indexWhere((c) => c.id == msg.conversationId);
          if (idx >= 0) {
            final c = updated[idx];
            final patched = Conversation(
              id: c.id,
              participants: c.participants,
              job: c.job,
              lastMessage: msg,
              unreadCount: isActiveConvo ? 0 : c.unreadCount + 1,
              createdAt: c.createdAt,
              updatedAt: msg.createdAt,
            );
            if (idx > 0) {
              updated.removeAt(idx);
              updated.insert(0, patched);
            } else {
              updated[0] = patched;
            }
          }
          _conversations = updated;
        }
      });

      if (!knownConvo) {
        _syncConversations();
      }

      if (isActiveConvo) {
        _scrollDown();
        _chat.markRead(_active!.id);
      }
    }));

    _subs.add(_chat.onConversationChanged.listen((_) {
      _syncConversations();
    }));

    _subs.add(_chat.onTyping.listen((event) {
      final me = ref.read(authProvider).user?.id;
      if (event.userId == me || !mounted) return;
      setState(() {
        _typingConvoId = event.conversationId;
        _typingPeerName =
            event.userName != null && event.userName!.trim().isNotEmpty ? event.userName!.trim() : null;
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
    }));

    _subs.add(_chat.onConnect.listen((_) {
      if (!mounted) return;
      setState(() { _socketConnected = true; _socketConnecting = false; });
      for (final c in _conversations) {
        _chat.joinRoom(c.id);
      }
    }));

    _subs.add(_chat.onDisconnect.listen((_) {
      if (!mounted) return;
      setState(() { _socketConnected = false; });
    }));

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

  int _optSeq = 0;

  Future<void> _send() async {
    final content = _inputCtrl.text.trim();
    if ((content.isEmpty && _selectedFile == null) || _active == null || _isSending) return;

    final fileToSend = _selectedFile;
    final me = ref.read(authProvider).user;
    if (me == null) return;

    // Validate file before sending
    if (fileToSend != null && !kIsWeb) {
      try {
        final file = File(fileToSend.path);
        final size = await file.length();
        if (!mounted) return;
        if (size > kMaxUploadBytes) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text('File is too large. Maximum size is 10 MB.'),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          return;
        }
      } catch (_) {
        if (!mounted) return;
      }

      final ext = fileToSend.name.split('.').last.toLowerCase();
      if (ext.isNotEmpty && !kAllowedUploadExtensions.contains(ext)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('.$ext files are not allowed.'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        return;
      }
    }

    final optId = 'opt-${DateTime.now().millisecondsSinceEpoch}-${_optSeq++}';
    final optimistic = Message(
      id: optId,
      conversationId: _active!.id,
      sender: me,
      content: content.isEmpty && fileToSend != null ? 'Attachment' : content,
      read: false,
      createdAt: DateTime.now().toIso8601String(),
    );

    // Single setState: lock send button, clear file, add optimistic message
    setState(() {
      _isSending = true;
      _selectedFile = null;
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

    _inputCtrl.clear();
    _lastTypingEmit = null;
    _scrollDown();

    try {
      final real = fileToSend != null
          ? await _chat.sendMessageWithFile(
              conversationId: _active!.id,
              content: content,
              filePath: kIsWeb ? null : fileToSend.path,
              fileName: fileToSend.name,
              fileBytes: kIsWeb ? await fileToSend.readAsBytes() : null,
            )
          : await _chat.sendMessageRest(_active!.id, content);
          
      if (!mounted) return;
      // Track confirmed ID so the socket echo is ignored.
      _confirmedMessageIds.add(real.id);
      setState(() {
        _messages = _messages.map((m) => m.id == optimistic.id ? real : m).toList();
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      final stillPending = _messages.any((m) => m.id == optimistic.id);
      if (!stillPending) return;
      // Remove the stuck optimistic message so the list stays clean
      setState(() {
        _messages = _messages.where((m) => m.id != optimistic.id).toList();
      });
      assert(() { debugPrint('SEND_ERR: ${_chat.extractError(e)}'); return true; }());
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

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null && mounted) setState(() => _selectedFile = picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await FilePicker.platform.pickFiles(type: FileType.any);
                if (!mounted) return;
                if (result != null && result.files.single.path != null) {
                  setState(() => _selectedFile = XFile(result.files.single.path!));
                } else if (result != null && result.files.single.bytes != null) {
                  setState(() => _selectedFile = XFile.fromData(result.files.single.bytes!, name: result.files.single.name));
                }
              },
            ),
          ],
        ),
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        if (!mounted) return;
        setState(() {
          _conversations = _conversations.where((c) => c.id != deletedId).toList();
          _active = null;
          _messages = [];
        });
        // If opened from a deep-link (/chat/:id), navigate back to the chat list.
        if (widget.conversationId != null) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/chat');
          }
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Failed to delete conversation. Please try again.'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
      }
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
                        if (_selectedFile == null)
                          IconButton(
                            icon: const Icon(Icons.attach_file, color: AppColors.textMuted),
                            padding: const EdgeInsets.only(bottom: 8),
                            constraints: const BoxConstraints(),
                            onPressed: _pickAttachment,
                          ),
                        if (_selectedFile == null)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedFile != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.insert_drive_file, size: 16, color: AppColors.navy),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text(_selectedFile!.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 8),
                                      InkWell(onTap: () => setState(() => _selectedFile = null), child: const Icon(Icons.close, size: 16, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ConstrainedBox(
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
                            ],
                          ),
                        ),
                       const SizedBox(width: 8),
                      ValueListenableBuilder(
                        valueListenable: _inputCtrl,
                        builder: (_, v, __) {
                          final hasContent = v.text.trim().isNotEmpty || _selectedFile != null;
                          return AnimatedOpacity(
                            opacity: hasContent && !_isSending ? 1.0 : 0.35,
                            duration: const Duration(milliseconds: 180),
                            child: GestureDetector(
                              onTap: hasContent && !_isSending ? _send : null,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.hasFile) ...[
                        if (msg.isImage)
                          GestureDetector(
                            onTap: () => _showImageModal(context, '${AppColors.staticOrigin}${msg.fileUrl}'),
                            child: Hero(
                              tag: 'chat_image_${msg.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: '${AppColors.staticOrigin}${msg.fileUrl}',
                                  placeholder: (context, url) => const SizedBox(width: 150, height: 150, child: Center(child: CircularProgressIndicator())),
                                  errorWidget: (context, url, error) => const SizedBox(width: 150, height: 150, child: Center(child: Icon(Icons.broken_image))),
                                  fit: BoxFit.cover,
                                  width: 200,
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () async {
                              final url = Uri.parse('${AppColors.staticOrigin}${msg.fileUrl}');
                              if (await canLaunchUrl(url)) await launchUrl(url);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white.withAlpha(51) : AppColors.navy.withAlpha(20),
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : AppColors.navy, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(msg.fileName ?? 'File', style: TextStyle(color: isMe ? Colors.white : AppColors.navy, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                          ),
                        if (msg.content.isNotEmpty) const SizedBox(height: 8),
                      ],
                      if (msg.content.isNotEmpty)
                        Text(
                          msg.content,
                          style: TextStyle(
                              fontSize: 14,
                              color: isMe ? Colors.white : AppColors.textBody,
                              height: 1.45),
                        ),
                    ],
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

  static void _showImageModal(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _FullScreenImageViewer(imageUrl: imageUrl),
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

// ── Full-Screen Image Viewer ────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

