import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chatbot_service.dart';
import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import '../services/user_service.dart';
import '../utils/image_utils.dart';
import '../widgets/index.dart';

class ChatbotPage extends StatefulWidget {
  final int userId;
  final String userRole;

  const ChatbotPage({
    super.key,
    required this.userId,
    this.userRole = 'aprendiz',
  });

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  static const Color _brandGreen = kBrandGreen;
  static const Color _pageBackground = kPageBackground;
  List<String> _suggestions = List<String>.from(ChatbotService.defaultSuggestions);

  late final String _chatKey;
  late final String _sessionsKey;

  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [];
  final List<ChatSession> _savedSessions = [];
  late ChatSession _currentSession;
  bool _isLoading = false;
  String _userAvatarPath = '';
  String _userAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _chatKey = _buildChatKey(widget.userId, widget.userRole);
    _sessionsKey = '${_chatKey}_sessions';
    _currentSession = _createSession();
    _messageController.addListener(_onDraftChanged);
    _loadUserAvatar();
    _loadSavedData();
  }

  void _onDraftChanged() {
    if (!mounted) return;
    if (_messageController.text.trim().isNotEmpty && _suggestions.isNotEmpty) {
      setState(() => _suggestions = []);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onDraftChanged);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAvatar() async {
    if (widget.userId <= 0) return;
    try {
      final user = await UserService.fetchUser(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _userAvatarPath = user.avatarPath ?? '';
        _userAvatarUrl = user.avatarUrl ?? '';
      });
      _applyAvatarToUserMessages();
    } catch (_) {}
  }

  void _applyAvatarToUserMessages() {
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (!m.isUser) continue;
      _messages[i] = ChatMessage(
        text: m.text,
        isUser: true,
        backgroundColor: m.backgroundColor,
        textColor: m.textColor,
        userAvatarPath: _userAvatarPath,
        userAvatarUrl: _userAvatarUrl,
      );
    }
  }

  ChatMessage _userMessage(String text) => ChatMessage(
        text: text,
        isUser: true,
        userAvatarPath: _userAvatarPath,
        userAvatarUrl: _userAvatarUrl,
      );

  String _buildChatKey(int userId, String userRole) {
    final normalizedRole =
        userRole.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return 'chat_history_${userId}_$normalizedRole';
  }

  String _deriveSessionTitle(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return 'Conversación nueva';

    const maxLen = 48;
    if (cleaned.length <= maxLen) return cleaned;

    return '${cleaned.substring(0, maxLen).trim()}…';
  }

  bool _isGenericSessionTitle(String title) {
    final value = title.trim().toLowerCase();
    return value == 'sesión actual' ||
        value == 'sesión cargada' ||
        value == 'conversación nueva' ||
        value.startsWith('sesión ');
  }

  void _applyTitleFromUserMessage(String text) {
    if (!_isGenericSessionTitle(_currentSession.title)) return;
    _currentSession.title = _deriveSessionTitle(text);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    SoundService.playClick();
    _applyTitleFromUserMessage(text);
    final userEntry = {'role': 'user', 'content': text};

    final userMsg = _userMessage(text);
    setState(() {
      _messages.add(userMsg);
      _chatHistory.add(userEntry);
      _currentSession.messages.add(userMsg);
      _currentSession.history.add(userEntry);
      _isLoading = true;
      _messageController.clear();
      _suggestions = [];
    });
    await _persistAll();

    try {
      final reply = await ChatbotService.instance.sendMessage(
        text,
        _chatHistory,
        userId: widget.userId,
      );
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: reply.text,
            isUser: false,
            useFormattedBotLayout: true,
          ));
          final botEntry = {'role': 'model', 'content': reply.text};
          _chatHistory.add(botEntry);
          _currentSession.messages.add(_messages.last);
          _currentSession.history.add(botEntry);
          _currentSession.updatedAt = DateTime.now();
          _upsertCurrentSession();
          _isLoading = false;
        });
        SoundService.playSuccess();
        await _persistAll();
      }
    } on ChatbotProfanityException catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _chatHistory.removeLast();
          _currentSession.messages.removeLast();
          _currentSession.history.removeLast();
          _messages.add(ChatMessage(
            text: e.message,
            isUser: false,
            backgroundColor: const Color(0xFFFFEBEE),
            textColor: const Color(0xFFB71C1C),
          ));
          _isLoading = false;
        });
        await _persistAll();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error: ${e.toString()}',
            isUser: false,
          ));
          _isLoading = false;
        });
        await _persistAll();
      }
    }
  }

  void _sendSuggestion(String text) {
    _messageController.text = text;
    _sendMessage();
  }

  bool get _hasUserMessages => _messages.any((message) => message.isUser);

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty || _isLoading || _hasUserMessages) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: _suggestions.asMap().entries.map((entry) {
          final index = entry.key;
          final suggestion = entry.value;
          return FadeSlideEntry(
            duration: Duration(milliseconds: 220 + (index % 5) * 40),
            verticalOffset: 16,
            curve: Curves.easeOutBack,
            child: ActionChip(
              label: Text(
                suggestion,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B5E20),
                ),
              ),
              backgroundColor: const Color(0xFFF1F8F2),
              side: const BorderSide(color: Color(0xFF81C784)),
              elevation: 2,
              shadowColor: Colors.black26,
              onPressed: () {
                SoundService.playClick();
                _sendSuggestion(suggestion);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _upsertCurrentSession() {
    if (_currentSession.messages.isEmpty) return;

    final index =
        _savedSessions.indexWhere((session) => session.id == _currentSession.id);
    if (index >= 0) {
      _savedSessions[index] = _currentSession;
    } else {
      _savedSessions.insert(0, _currentSession);
    }
  }

  ChatSession _createSession({String? title}) {
    final now = DateTime.now();
    return ChatSession(
      id: now.microsecondsSinceEpoch.toString(),
      title: title ?? 'Conversación nueva',
      createdAt: now,
      updatedAt: now,
      messages: [],
      history: [],
    );
  }

  String _formatSessionDate(DateTime createdAt) {
    final local = createdAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  void _showChatHistory() {
    _upsertCurrentSession();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sessions = List<ChatSession>.from(_savedSessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Historial de conversaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _createNewSession();
                      },
                      child: const Text('Nueva sesión'),
                    ),
                  ],
                ),
              ),
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aún no hay sesiones guardadas. Envía un mensaje para crear una.',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isCurrent = session.id == _currentSession.id;
                      return ListTile(
                        leading: Icon(
                          isCurrent
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                          color: isCurrent ? _brandGreen : null,
                        ),
                        title: Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_formatSessionDate(session.updatedAt)),
                        onTap: () => _loadChatSession(session),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _loadChatSession(ChatSession session) {
    Navigator.of(context).pop();
    setState(() {
      _currentSession = session;
      _messages
        ..clear()
        ..addAll(session.messages);
      _chatHistory
        ..clear()
        ..addAll(session.history);
    });
    _persistAll();
  }

  Future<void> _createNewSession() async {
    _upsertCurrentSession();
    final newSession = _createSession();
    setState(() {
      _currentSession = newSession;
      _messages.clear();
      _chatHistory.clear();
    });
    await _persistAll();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString(_sessionsKey);
    final currentId = prefs.getString('${_chatKey}_current_id');

    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(sessionsJson) as List<dynamic>;
        final sessions = decoded
            .whereType<Map<String, dynamic>>()
            .map(ChatSession.fromJson)
            .where((session) => session.messages.isNotEmpty)
            .toList();

        if (sessions.isNotEmpty) {
          setState(() {
            _savedSessions
              ..clear()
              ..addAll(sessions);
          });

          ChatSession? restored;
          if (currentId != null) {
            for (final session in sessions) {
              if (session.id == currentId) {
                restored = session;
                break;
              }
            }
          }
          restored ??= sessions.first;

          setState(() {
            _currentSession = restored!;
            _messages
              ..clear()
              ..addAll(restored.messages);
            _chatHistory
              ..clear()
              ..addAll(restored.history);
          });
          _applyAvatarToUserMessages();
          return;
        }
      } catch (_) {
        // Continuar con formato antiguo.
      }
    }

    await _loadLegacyMessages(prefs);
    _applyAvatarToUserMessages();
  }

  Future<void> _loadLegacyMessages(SharedPreferences prefs) async {
    final savedJson = prefs.getString(_chatKey);
    if (savedJson == null || savedJson.isEmpty) return;

    try {
      final decoded = jsonDecode(savedJson) as List<dynamic>;
      final restoredMessages = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => ChatMessage(
                text: item['text']?.toString() ?? '',
                isUser: item['isUser'] == true,
              ))
          .where((message) => message.text.isNotEmpty)
          .toList();

      if (restoredMessages.isEmpty) return;

      final firstUser = restoredMessages.firstWhere(
        (message) => message.isUser,
        orElse: () => restoredMessages.first,
      );

      final session = _createSession(
        title: firstUser.isUser
            ? _deriveSessionTitle(firstUser.text)
            : 'Conversación guardada',
      );
      session.messages.addAll(restoredMessages);
      session.history.addAll(_buildChatHistoryFromMessages(restoredMessages));

      setState(() {
        _currentSession = session;
        _messages
          ..clear()
          ..addAll(restoredMessages);
        _chatHistory
          ..clear()
          ..addAll(session.history);
        _savedSessions.insert(0, session);
      });
      await _persistAll();
    } catch (_) {
      // Ignorar datos corruptos.
    }
  }

  List<Map<String, String>> _buildChatHistoryFromMessages(
      List<ChatMessage> messages) {
    final history = <Map<String, String>>[];
    for (final message in messages) {
      final role = message.isUser ? 'user' : 'model';
      if (history.isNotEmpty && history.last['role'] == role) {
        history.last['content'] = '${history.last['content']}\n${message.text}';
      } else {
        history.add({'role': role, 'content': message.text});
      }
    }
    return history;
  }

  Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    _upsertCurrentSession();

    final sessionsPayload = _savedSessions
        .where((session) => session.messages.isNotEmpty)
        .map((session) => session.toJson())
        .toList();

    await prefs.setString(_sessionsKey, jsonEncode(sessionsPayload));
    await prefs.setString('${_chatKey}_current_id', _currentSession.id);

    final encoded = jsonEncode(_messages
        .map((message) => {
              'text': message.text,
              'isUser': message.isUser,
              if (message.backgroundColor != null)
                'backgroundColor': message.backgroundColor!.toARGB32(),
              if (message.textColor != null)
                'textColor': message.textColor!.toARGB32(),
            })
        .toList());
    await prefs.setString(_chatKey, encoded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Asistente Q-LESS'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial de chat',
            onPressed: _showChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hola, soy tu guía de proyectos Q-LESS',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pregúntame sobre materiales o pasos para tu proyecto',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _buildSuggestions(),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _messages[index];
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TypingIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu pregunta...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                InteractiveScaleButton(
                  onTap: _isLoading ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _brandGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    required this.history,
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;
  final List<Map<String, String>> history;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((message) => message.toJson()).toList(),
        'history': history,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Conversación',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
      history: (json['history'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((entry) => {
                'role': entry['role']?.toString() ?? 'user',
                'content': entry['content']?.toString() ?? '',
              })
          .toList(),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat();

  double _opacityTarget = 0.85;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: _opacityTarget),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {
        setState(() {
          _opacityTarget = _opacityTarget == 1.0 ? 0.82 : 1.0;
        });
      },
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3EC13B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Asistente está escribiendo...',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final Color? backgroundColor;
  final Color? textColor;
  final String? userAvatarPath;
  final String? userAvatarUrl;
  final bool useFormattedBotLayout;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.backgroundColor,
    this.textColor,
    this.userAvatarPath,
    this.userAvatarUrl,
    this.useFormattedBotLayout = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        if (backgroundColor != null) 'backgroundColor': backgroundColor!.toARGB32(),
        if (textColor != null) 'textColor': textColor!.toARGB32(),
        'useFormattedBotLayout': useFormattedBotLayout,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      backgroundColor: json['backgroundColor'] is int
          ? Color(json['backgroundColor'] as int)
          : null,
      textColor:
          json['textColor'] is int ? Color(json['textColor'] as int) : null,
      useFormattedBotLayout: json['useFormattedBotLayout'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3EC13B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor ??
                      (isUser ? const Color(0xFF3EC13B) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: !isUser
                      ? Border.all(color: const Color(0xFFD7E8D8))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: !isUser && useFormattedBotLayout
                    ? BotFormattedContent(text: text)
                    : Text(
                        text,
                        style: TextStyle(
                          color: textColor ??
                              (isUser ? Colors.white : Colors.black87),
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              buildUserAvatar(
                avatarPath: userAvatarPath ?? '',
                avatarUrl: userAvatarUrl ?? '',
                size: 36,
              ),
            ],
          ],
        ),
    );
  }
}

class BotFormattedContent extends StatelessWidget {
  final String text;

  const BotFormattedContent({super.key, required this.text});

  static const _sectionTitles = [
    'MATERIALES',
    'PASOS',
    'DISPONIBLES EN PRODUCTOS',
    'CONSEJOS',
  ];

  static const _sectionColors = {
    'MATERIALES': Color(0xFF2E7D32),
    'PASOS': Color(0xFF43A047),
    'DISPONIBLES EN PRODUCTOS': Color(0xFF388E3C),
    'CONSEJOS': Color(0xFF66BB6A),
  };

  List<Map<String, String>> _parseSections(String raw) {
    final sections = <Map<String, String>>[];
    final pattern = RegExp(
      r'(MATERIALES|PASOS|DISPONIBLES EN PRODUCTOS|CONSEJOS)\s*\n?',
      caseSensitive: false,
    );
    final matches = pattern.allMatches(raw).toList();

    if (matches.isEmpty) {
      return [
        {'title': '', 'body': raw.trim()},
      ];
    }

    for (var i = 0; i < matches.length; i++) {
      final title = matches[i].group(1)!.toUpperCase();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : raw.length;
      final body = raw.substring(start, end).trim();
      sections.add({'title': title, 'body': body});
    }
    return sections;
  }

  List<String> _parseLines(String body) {
    return body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Widget _buildProductRow(String line) {
    final cleaned = line.replaceFirst(RegExp(r'^[-•]\s*'), '');
    final parts = cleaned.split('·').map((p) => p.trim()).toList();
    final name = parts.isNotEmpty ? parts[0] : cleaned;
    final category = parts.length > 1 ? parts[1] : '';
    final price = parts.length > 2 ? parts[2] : '';
    final stock = parts.length > 3 ? parts[3] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                if (category.isNotEmpty)
                  Text(
                    category,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (price.isNotEmpty)
                      Text(
                        price,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    if (stock.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          stock,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(String line, int index, bool numbered) {
    final cleaned = line.replaceFirst(RegExp(r'^[-•]\s*'), '');
    final stepText = numbered
        ? cleaned.replaceFirst(RegExp(r'^\d+[\).\s-]+'), '')
        : cleaned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              numbered ? '${index + 1}' : '•',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stepText.isEmpty ? cleaned : stepText,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        final title = section['title'] ?? '';
        final body = section['body'] ?? '';
        final lines = _parseLines(body);
        final accent = _sectionColors[title] ?? const Color(0xFF43A047);
        final isProducts = title == 'DISPONIBLES EN PRODUCTOS';
        final isSteps = title == 'PASOS';

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: accent,
                    ),
                  ),
                ),
              if (isProducts)
                ...lines.map(_buildProductRow)
              else if (lines.isEmpty)
                Text(body, style: const TextStyle(fontSize: 14, height: 1.35))
              else
                ...lines.asMap().entries.map(
                      (entry) => _buildListItem(
                        entry.value,
                        entry.key,
                        isSteps || RegExp(r'^\d+[\).\s-]').hasMatch(entry.value),
                      ),
                    ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
