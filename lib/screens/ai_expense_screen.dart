import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../models/group.dart';
import '../providers/split_provider.dart';
import '../services/gemini_ai_service.dart';
import '../widgets/ai_header.dart';
import '../widgets/ai_prompt_input.dart';
import '../widgets/ai_result_card.dart';
import '../widgets/ai_input_footer.dart';
import '../widgets/group_selector_card.dart';
import '../widgets/receipt_upload_card.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/ai_chat_view.dart';

class AiExpenseScreen extends StatefulWidget {
  const AiExpenseScreen({super.key});

  @override
  State<AiExpenseScreen> createState() => _AiExpenseScreenState();
}

class _AiExpenseScreenState extends State<AiExpenseScreen> {
  final TextEditingController promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _promptKey = GlobalKey();
  final GlobalKey _resultKey = GlobalKey();

  final GeminiAiService _aiService = GeminiAiService();

  Uint8List? _receiptBytes;
  bool _loading = false;
  Map<String, dynamic>? _aiResult;
  Group? _selectedGroup;

  // Ask Anything Mode State
  bool _isAskMode = false;
  final List<AiGeneralMessage> _chatMessages = [];
  bool _isChatLoading = false;

  @override
  void dispose() {
    promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _saveExpense() {
    final provider = context.read<SplitProvider>();

    final result = _aiResult!;
    final payerName = result["payerName"] as String;
    final splitMapRaw = result["splitMap"] as Map<String, dynamic>;

    // Robust name matching for payer
    int? payerId;
    for (final p in _selectedGroup!.members) {
      if (p.name.toLowerCase() == payerName.toLowerCase()) {
        payerId = p.id;
        break;
      }
    }

    // Fallback to first member if AI misidentified
    payerId ??= _selectedGroup!.members.first.id;

    final Map<int, double> customSplits = {};
    final Set<int> splitWith = {};

    splitMapRaw.forEach((name, amount) {
      for (final p in _selectedGroup!.members) {
        if (p.name.toLowerCase() == name.toLowerCase()) {
          splitWith.add(p.id);
          customSplits[p.id] = (amount as num).toDouble();
          break;
        }
      }
    });

    // If splitWith is empty (AI didn't use group names), default to everyone
    if (splitWith.isEmpty) {
      for (final p in _selectedGroup!.members) {
        splitWith.add(p.id);
      }
    }

    final error = provider.addExpense(
      desc: result["description"] ?? "AI Expense",
      amount: (result["amount"] as num).toDouble(),
      payerId: payerId,
      splitWith: splitWith,
      customSplits: customSplits.isEmpty ? null : customSplits,
    );

    if (error != null) {
      _showSnack(error);
    } else {
      _showSnack("Expense added successfully! ✅");
      if (mounted) Navigator.pop(context);
    }
  }

  void _scrollToPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_promptKey.currentContext != null) {
        Scrollable.ensureVisible(
          _promptKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _scrollToResult() {
    // Wait for the result card to be built and for keyboard to hide
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_resultKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultKey.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  Future<void> _analyseExpense() async {
    FocusScope.of(context).unfocus(); // Close keyboard
    if (_selectedGroup == null) {
      _showSnack("Choose a group first.");
      return;
    }

    if (_receiptBytes == null && promptController.text.trim().isEmpty) {
      _showSnack(
        "Upload a receipt or describe the expense.",
      );
      return;
    }

    setState(() {
      _loading = true;
      _aiResult = null;
    });

    try {
      final members = _selectedGroup!.members.map((e) => e.name).toList();

      final result = await _aiService.parseBillWithVision(
        imageBytes: _receiptBytes, // Now optional
        instructions: promptController.text,
        memberNames: members,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _aiResult = result;
      });

      if (result != null) {
        _scrollToResult();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (e.toString().toLowerCase().contains('quota')) {
        _showSnack("AI is busy (Free Tier limits). Please wait 30s and retry!");
      } else {
        _showSnack("Error: $e");
      }
    }
  }

  Future<void> _askGeneralQuestion() async {
    final query = promptController.text.trim();
    if (query.isEmpty) return;

    final provider = context.read<SplitProvider>();
    final appContext = provider.getAiSummaryContext();

    setState(() {
      _chatMessages.add(AiGeneralMessage(text: query, isUser: true));
      promptController.clear();
      _isChatLoading = true;
    });
    _scrollToChatBottom();

    try {
      final response = await _aiService.queryAppState(
        userQuery: query,
        appContext: appContext,
      );

      if (!mounted) return;

      setState(() {
        _isChatLoading = false;
        _chatMessages.add(AiGeneralMessage(text: response ?? "I'm not sure how to answer that.", isUser: false));
      });
      _scrollToChatBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChatLoading = false);
      _showSnack("Error: $e");
    }
  }

  void _scrollToChatBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.8),
            radius: 1.4,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              /// Header
              const AiHeader(),

              /// Mode Selector
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: 'SPLIT BILL',
                        isActive: !_isAskMode,
                        onTap: () => setState(() => _isAskMode = false),
                      ),
                      _ModeButton(
                        label: 'ASK ANYTHING',
                        isActive: _isAskMode,
                        onTap: () => setState(() => _isAskMode = true),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _isAskMode
                    ? AiChatView(
                        messages: _chatMessages,
                        isLoading: _isChatLoading,
                        scrollController: _chatScrollController,
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.all(20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            /// Group
                            GroupSelectorCard(
                              selectedGroup: _selectedGroup,
                              onGroupChanged: (group) {
                                setState(() {
                                  _selectedGroup = group;
                                  _aiResult = null; // Reset AI result when group changes
                                });
                              },
                            ),
                            22.verticalSpace,

                            /// Receipt Upload
                            ReceiptUploadCard(
                              imageBytes: _receiptBytes,
                              onImageSelected: (bytes) {
                                setState(() {
                                  _receiptBytes = bytes;
                                });
                                if (bytes != null) {
                                  _scrollToPrompt();
                                }
                              },
                            ),

                            22.verticalSpace,

                            /// Prompt
                            AiPromptInput(
                              key: _promptKey,
                              controller: promptController,
                            ),

                            if (_loading) ...[
                              30.verticalSpace,
                              const TypingIndicator(),
                            ],

                            if (_aiResult != null) ...[
                              30.verticalSpace,
                              AiResultCard(
                                key: _resultKey,
                                result: _aiResult!,
                                currency: _selectedGroup?.currency ?? "AED",
                                onSave: _saveExpense,
                                onEdit: () {
                                  setState(() {
                                    _aiResult = null;
                                  });
                                },
                              ),
                            ],

                            32.verticalSpace,
                          ],
                        ),
                      ),
              ),

              AiInputFooter(
                isAskMode: _isAskMode,
                loading: _isAskMode ? _isChatLoading : _loading,
                controller: promptController,
                onAction: _isAskMode ? _askGeneralQuestion : _analyseExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brass : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppColors.ink : AppColors.slate,
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
