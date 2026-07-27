import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/ai_chat_message.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../providers/split_provider.dart';
import '../services/gemini_ai_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class AiExpenseScreen extends StatefulWidget {
  const AiExpenseScreen({super.key});

  @override
  State<AiExpenseScreen> createState() => _AiExpenseScreenState();
}

class _AiExpenseScreenState extends State<AiExpenseScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final GeminiAiService _aiService = GeminiAiService();

  final List<AiChatMessage> _messages = [];
  
  XFile? _selectedImage;
  Group? _selectedGroup;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _addAiMessage('Welcome to Nus·Nus AI Assistant! 🪄\n\nTo get started, upload a receipt or describe an expense you\'d like to split.');
  }

  void _addAiMessage(String text, {AiChatMessageType type = AiChatMessageType.text, dynamic metadata}) {
    setState(() {
      _messages.add(AiChatMessage(text: text, isUser: false, type: type, metadata: metadata));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text, {String? imagePath}) {
    setState(() {
      _messages.add(AiChatMessage(text: text, isUser: true, type: AiChatMessageType.text, imagePath: imagePath));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleImagePick() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      _selectedImage = image;
      _addUserMessage('Attached a receipt', imagePath: image.path);
      
      // Next Step: Ask for Group
      _addAiMessage('Got the receipt! 📸 Which group should I add this expense to?', type: AiChatMessageType.groupPicker);
    }
  }

  void _handleGroupSelected(Group group) {
    setState(() {
      _selectedGroup = group;
    });
    _addUserMessage('Selected group: ${group.name}');
    
    // Show members and ask for instructions
    _addAiMessage(
      'Great! I\'ll use the members from "${group.name}". Any specific instructions for the split?',
      type: AiChatMessageType.memberHint,
      metadata: group.members,
    );
  }

  Future<void> _handleSendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    _textCtrl.clear();
    _addUserMessage(text);

    if (_selectedGroup == null) {
      _addAiMessage('Please select a group first so I know who we\'re splitting with!', type: AiChatMessageType.groupPicker);
      return;
    }

    _generateSplit(text);
  }

  Future<void> _generateSplit(String instructions) async {
    if (_selectedGroup == null) return;
    
    setState(() => _isGenerating = true);
    _addAiMessage('Analyzing your request and calculating the split... ⏳');

    try {
      final members = _selectedGroup!.members.map((p) => p.name).toList();
      
      Uint8List? imageBytes;
      if (_selectedImage != null) {
        imageBytes = await _selectedImage!.readAsBytes();
      }

      final result = await _aiService.parseBillWithVision(
        imageBytes: imageBytes ?? Uint8List(0),
        instructions: instructions.isEmpty 
            ? "Split this bill evenly among all members." 
            : "SPLIT INSTRUCTIONS: $instructions",
        memberNames: members,
      );

      if (result != null) {
        _addAiMessage(
          'Here is what I found! Please review and confirm to save.',
          type: AiChatMessageType.resultPreview,
          metadata: result,
        );
      } else {
        _addAiMessage('Sorry, I had trouble parsing that. Could you try describing it more clearly or uploading a better photo?');
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('quota')) {
        _addAiMessage('The AI is currently a bit busy (Free Tier limits). Please wait about 30 seconds and try again! ☕');
      } else {
        _addAiMessage('An error occurred during analysis: $e');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _saveExpense(Map<String, dynamic> aiResult) {
    if (_selectedGroup == null) return;
    
    final provider = context.read<SplitProvider>();
    final description = aiResult['description'] as String;
    final totalAmount = (aiResult['amount'] as num).toDouble();
    final payerName = aiResult['payerName'] as String;
    final splitMapRaw = aiResult['splitMap'] as Map<String, dynamic>;

    // Map names back to IDs within the specific group
    int? payerId;
    for (final p in _selectedGroup!.members) {
      if (p.name.toLowerCase() == payerName.toLowerCase()) {
        payerId = p.id;
        break;
      }
    }

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

    final error = provider.addExpense(
      desc: description,
      amount: totalAmount,
      payerId: payerId ?? _selectedGroup!.members.first.id,
      splitWith: splitWith,
      customSplits: customSplits,
    );

    if (error != null) {
      _addAiMessage('Failed to save: $error');
    } else {
      _addAiMessage('Expense saved successfully! ✅');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.paper),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nus·Nus AI Chat', style: TextStyle(color: AppColors.paper, fontWeight: FontWeight.bold, fontSize: 18.sp)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsets.all(16.w),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          
          if (_isGenerating)
            const _TypingIndicator(),

          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    return Column(
      crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (msg.imagePath != null)
          Container(
            margin: EdgeInsets.only(bottom: 8.h),
            height: 200.h,
            width: 150.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              image: DecorationImage(image: FileImage(File(msg.imagePath!)), fit: BoxFit.cover),
            ),
          ),
        
        if (msg.type == AiChatMessageType.text)
          Container(
            margin: EdgeInsets.only(bottom: 16.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            constraints: BoxConstraints(maxWidth: 0.75.sw),
            decoration: BoxDecoration(
              color: msg.isUser ? AppColors.brass : AppColors.paper,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(msg.isUser ? 16.r : 0),
                bottomRight: Radius.circular(msg.isUser ? 0 : 16.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        if (msg.type == AiChatMessageType.groupPicker)
          _GroupPickerBubble(
            groups: context.read<SplitProvider>().groups,
            onSelected: _handleGroupSelected,
          ),

        if (msg.type == AiChatMessageType.memberHint)
          _MemberHintBubble(people: msg.metadata as List<Person>),

        if (msg.type == AiChatMessageType.resultPreview)
          _AiResultPreviewBubble(
            result: msg.metadata as Map<String, dynamic>,
            onSave: () => _saveExpense(msg.metadata),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.paperDim.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_a_photo, color: AppColors.brass, size: 24.r),
              onPressed: _handleImagePick,
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Type instructions...',
                    hintStyle: TextStyle(color: AppColors.slate),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _handleSendText(),
                ),
              ),
            ),
            8.horizontalSpace,
            CircleAvatar(
              backgroundColor: AppColors.brass,
              child: IconButton(
                icon: const Icon(Icons.send, color: AppColors.ink, size: 18),
                onPressed: _handleSendText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPickerBubble extends StatelessWidget {
  final List<Group> groups;
  final Function(Group) onSelected;

  const _GroupPickerBubble({required this.groups, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      height: 60.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final g = groups[index];
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ActionChip(
              backgroundColor: AppColors.paper,
              label: Text(g.name, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
              onPressed: () => onSelected(g),
            ),
          );
        },
      ),
    );
  }
}

class _MemberHintBubble extends StatelessWidget {
  final List<Person> people;
  const _MemberHintBubble({required this.people});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IDENTIFIED MEMBERS:',
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: AppColors.slate, letterSpacing: 1),
          ),
          8.verticalSpace,
          Wrap(
            spacing: 6.w,
            children: people.map((p) => Chip(
              backgroundColor: AppColors.ink,
              avatar: CircleAvatar(backgroundColor: p.color, radius: 8.r),
              label: Text(p.name, style: TextStyle(color: AppColors.paper, fontSize: 10.sp)),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _AiResultPreviewBubble extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onSave;

  const _AiResultPreviewBubble({required this.result, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final splitMap = result['splitMap'] as Map<String, dynamic>;
    final currency = context.read<SplitProvider>().currentGroup?.currency ?? 'AED';

    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.brass.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.brass, size: 20.r),
                8.horizontalSpace,
                Text('AI SPLIT READY', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.brass, fontSize: 12.sp, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['description'].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontFamily: 'Georgia', fontSize: 16.sp)),
                8.verticalSpace,
                Text(fmtCurrency((result['amount'] as num).toDouble(), currency), style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink, fontSize: 24.sp)),
                Divider(height: 24.h),
                ...splitMap.entries.map((e) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                      Text(fmtCurrency((e.value as num).toDouble(), currency), style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 12.sp)),
                    ],
                  ),
                )),
                20.verticalSpace,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: const Text('CONFIRM & SAVE'),
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nus Ai is processing',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                12.horizontalSpace,
                _DotPulsing(controller: _controller, index: 0),
                4.horizontalSpace,
                _DotPulsing(controller: _controller, index: 1),
                4.horizontalSpace,
                _DotPulsing(controller: _controller, index: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPulsing extends StatelessWidget {
  final AnimationController controller;
  final int index;
  const _DotPulsing({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double value = (controller.value * 3 - index) % 3;
        final double opacity = (1.0 - (value - 1.0).abs()).clamp(0.2, 1.0);
        return Container(
          height: 4.r,
          width: 4.r,
          decoration: BoxDecoration(
            color: AppColors.brass.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
