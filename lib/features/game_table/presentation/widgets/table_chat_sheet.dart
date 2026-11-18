import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../controllers/game_table_controller.dart';

/// In-table chat & quick-reactions modal sheet.
class TableChatSheet extends StatefulWidget {
  const TableChatSheet({
    super.key,
    required this.controller,
  });

  final GameTableController controller;

  @override
  State<TableChatSheet> createState() => _TableChatSheetState();
}

class _TableChatSheetState extends State<TableChatSheet> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitCustomMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.controller.sendChatMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.76,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final messages = widget.controller.chatMessages;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFFF0E9D8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Table Chat & Reactions',
                            style: AppTextStyles.modalHeadingCream,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),

                    // Quick Emoji Reactions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: GameTableController.quickEmojis.map((emoji) {
                        return InkWell(
                          onTap: () {
                            widget.controller.sendQuickReaction(emoji);
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 44,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Quick Teen Patti Phrases
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: GameTableController.quickPhrases.map((phrase) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              backgroundColor: const Color(0xFF19422B),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              label: Text(
                                phrase,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFF0E9D8),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.sendChatMessage(phrase);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Live Chat Feed
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 110),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${msg.senderName}: ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: msg.isLocal
                                        ? const Color(0xFF9DF0B8)
                                        : const Color(0xFFF0E9D8),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color:
                                          Colors.white.withValues(alpha: 0.90),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom Message Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.white,
                            ),
                            onSubmitted: (_) => _submitCustomMessage(),
                            decoration: InputDecoration(
                              hintText: 'Say something to the table...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.48),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submitCustomMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF0E9D8),
                            foregroundColor: const Color(0xFF142E1F),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            'Send',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
