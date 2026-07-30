import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/person.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/currency_formatter.dart';

class AiResultEditor extends StatefulWidget {
  final Map<String, dynamic> result;
  final List<Person> members;
  final String currency;
  final Function(Map<String, dynamic>) onSave;

  const AiResultEditor({
    super.key,
    required this.result,
    required this.members,
    required this.currency,
    required this.onSave,
  });

  @override
  State<AiResultEditor> createState() =>
      _AiResultEditorState();
}

class _AiResultEditorState
    extends State<AiResultEditor> {

  late TextEditingController descriptionCtrl;
  late TextEditingController amountCtrl;

  late String payer;

  late Set<String> selectedMembers;

  @override
  void initState() {
    super.initState();

    descriptionCtrl =
        TextEditingController(
          text: widget.result["description"],
        );

    amountCtrl =
        TextEditingController(
          text:
          widget.result["amount"].toString(),
        );

    payer =
    widget.result["payerName"];

    selectedMembers =
        widget.members
            .map((e) => e.name)
            .toSet();
  }

  @override
  void dispose() {
    descriptionCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  double get total =>
      double.tryParse(
        amountCtrl.text,
      ) ??
          0;

  double get share =>
      selectedMembers.isEmpty
          ? 0
          : total /
          selectedMembers.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius:
        BorderRadius.circular(28.r),
      ),
      child: Column(
        children: [

          Row(
            children: [

              Icon(
                Icons.auto_awesome,
                color:
                AppColors.brass,
              ),

              8.horizontalSpace,

              Text(
                "Review AI Result",
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
            ],
          ),

          24.verticalSpace,

          TextField(
            controller:
            descriptionCtrl,
            decoration:
            const InputDecoration(
              labelText:
              "Description",
            ),
          ),

          18.verticalSpace,

          TextField(
            controller: amountCtrl,
            keyboardType:
            TextInputType.number,
            onChanged: (_) {
              setState(() {});
            },
            decoration:
            const InputDecoration(
              labelText:
              "Amount",
            ),
          ),

          18.verticalSpace,

          DropdownButtonFormField<String>(
            initialValue: payer,
            decoration:
            const InputDecoration(
              labelText:
              "Paid By",
            ),
            items:
            widget.members
                .map(
                  (e) =>
                  DropdownMenuItem(
                    value:
                    e.name,
                    child:
                    Text(
                      e.name,
                    ),
                  ),
            )
                .toList(),
            onChanged:
                (value) {
              setState(() {
                payer = value!;
              });
            },
          ),

          26.verticalSpace,

          Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              "Split Between",
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
          ),

          12.verticalSpace,

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
            widget.members
                .map(
                    (person) {
                  final selected =
                  selectedMembers
                      .contains(
                      person.name);

                  return FilterChip(
                    selected:
                    selected,
                    label: Text(
                      person.name,
                    ),
                    avatar:
                    CircleAvatar(
                      radius: 10,
                      backgroundColor:
                      person.color,
                    ),
                    onSelected:
                        (value) {
                      setState(() {
                        if (value) {
                          selectedMembers.add(
                              person
                                  .name);
                        } else {
                          selectedMembers
                              .remove(
                              person
                                  .name);
                        }
                      });
                    },
                  );
                }).toList(),
          ),

          24.verticalSpace,

          Container(
            padding:
            EdgeInsets.all(16),
            decoration:
            BoxDecoration(
              color:
              Colors.grey.shade100,
              borderRadius:
              BorderRadius.circular(
                  16),
            ),
            child: Column(
              children:
              selectedMembers
                  .map(
                    (member) =>
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                          vertical:
                          6),
                      child: Row(
                        children: [

                          Expanded(
                            child:
                            Text(
                              member,
                            ),
                          ),

                          Text(
                            fmtCurrency(
                              share,
                              widget
                                  .currency,
                            ),
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ],
                      ),
                    ),
              )
                  .toList(),
            ),
          ),

          24.verticalSpace,

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                widget.onSave({
                  "description":
                  descriptionCtrl
                      .text,
                  "amount":
                  total,
                  "payerName":
                  payer,
                  "splitMembers":
                  selectedMembers
                      .toList(),
                });
              },
              style:
              FilledButton.styleFrom(
                backgroundColor:
                AppColors.sage,
              ),
              icon:
              const Icon(Icons.check),
              label: const Text(
                  "Save Expense"),
            ),
          ),
        ],
      ),
    );
  }
}