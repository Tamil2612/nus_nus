import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection('1. Information we handle', paragraphs: [
      'Account and profile information: your name, email address, password authentication data, and any phone number you add to your profile. Firebase Authentication handles sign-in credentials; Nus·Nus does not receive or store your account password in the app profile.',
      'Contact matching: if you grant contact access, the app reads contact phone numbers on your device and securely sends batches of up to 100 numbers to check which discoverable accounts match. Contact names and other address-book fields are not sent. Numbers are processed for matching and are not saved as a contact list or lookup history. To prevent abuse, we limit searches to 5 calls per minute and 1,000 numbers per day per account. You can turn off “Let contacts find me” in your profile settings. You can also enter a phone number for a one-number lookup.',
      'Group and financial information: group names and settings, member names and account links, expense descriptions, amounts, currencies, payers, split details, balances, and settlement records. Nus·Nus records settlement status; it does not move money or verify an external payment.',
      'Chat and images: messages, sender display names, timestamps, and images you choose to share in a group. Group members with access can view this content. Chat images are stored in Firebase Storage.',
      'AI requests: receipt images and instructions are sent to the Gemini API through the backend when you use receipt parsing. Questions to Nus·Nus AI and relevant app context, such as group, expense, member, and balance details, are sent to Gemini to generate answers. AI suggestions can be inaccurate; review them before acting on them.',
      'Notifications and device information: if you enable push notifications, the device Firebase Cloud Messaging token is stored in a private account record. Notifications may include a group name, sender name, short chat preview, or expense description and your share amount. Your notification preference is also stored on your device.',
      'Service and security data: platform information, account identifiers, timestamps, App Check data and integrity signals where enabled, and technical records needed to operate the Service, prevent abuse, and troubleshoot failures. Firebase and Google may process network and device information as described in their documentation.',
    ]),
    _PolicySection('2. Why we use information', bullets: [
      'Create and secure accounts and maintain profiles.',
      'Provide personal ledgers, shared groups, chat, expenses, and balances.',
      'Match contact phone numbers with registered accounts when requested.',
      'Send notifications you enable and open the relevant group or expense.',
      'Provide AI-assisted receipt parsing and answers when you use those features.',
      'Protect the Service, enforce account and group actions, fix errors, and meet legal obligations.',
    ]),
    _PolicySection('3. When information is shared', paragraphs: [
      'Information you add to a shared group is available to members with access to that group. Consider this before adding chat messages, images, or expense details.',
      'We use Google Firebase for authentication, database, file storage, backend functions, hosting, app integrity checks, and push notifications. Google’s Gemini API provides the AI features described above. These providers process information under their applicable terms and privacy documentation.',
      'Information may be disclosed if required by law or reasonably necessary to protect users, the Service, or the public. It may also be transferred as part of a merger, financing, reorganization, or sale of the Service, subject to applicable law and safeguards.',
      'We do not sell personal information.',
    ]),
    _PolicySection('4. AI provider handling', paragraphs: [
      'AI requests are sent to Google’s Gemini API. Google’s handling of prompts, images, and responses depends on the service tier and terms that apply to the API project; Google’s terms distinguish between unpaid and paid services. Avoid sending passwords, payment card details, identity documents, or other highly sensitive information to AI features.',
    ], links: [
      _PolicyLink('Gemini API Additional Terms',
          'https://ai.google.dev/gemini-api/terms'),
      _PolicyLink(
          'Google Privacy Policy', 'https://policies.google.com/privacy'),
    ]),
    _PolicySection('5. Retention and account deletion', paragraphs: [
      'We keep account and Service information while needed to provide the Service, comply with law, resolve disputes, and protect against abuse. Retention can differ by information type and provider.',
      'You can request account deletion in the app after confirming your password. Your profile, authentication account, personal ledger, private push-token data, and contact-matching rate-limit record are deleted. Before deletion, you must choose whether each shared group you own will be transferred to an eligible member or deleted with its history.',
      'If a shared group is retained, its expenses and text messages remain with the group in anonymized form. Displayed member and chat sender names are replaced with “Former member” and active group membership is removed. Chat images uploaded by the deleted account are removed from storage, and their message references are removed; image-only messages are replaced with “[image removed]”. If a group is deleted, its associated records and chat images are removed as part of that deletion. Provider backups and legally required records may persist for a limited period under provider practices or applicable law.',
    ]),
    _PolicySection('6. Your choices and requests', bullets: [
      'You can deny contact access and add a member using a phone number instead.',
      'You can turn push notifications off in the app or your device settings.',
      'You can review or update profile information in the app.',
      'You can request account deletion from the profile screen.',
      'Depending on where you live, you may have rights to access, correct, export, restrict, or object to processing. Contact us to make a request.',
    ]),
    _PolicySection('7. Security and international processing', paragraphs: [
      'We use Firebase authentication, access rules, and provider security controls to protect information. No online service can guarantee absolute security. Google may process information in countries where it or its service providers operate; applicable provider terms and safeguards govern those transfers.',
    ], links: [
      _PolicyLink('Firebase Privacy and Security',
          'https://firebase.google.com/support/privacy/'),
    ]),
    _PolicySection('8. Children', paragraphs: [
      'Nus·Nus is not designed for children under 13, and we do not knowingly permit them to create accounts. If you believe a child has provided personal information, contact us so we can review and address it.',
    ]),
    _PolicySection('9. Changes to this policy', paragraphs: [
      'We may update this policy as the Service changes or as required by law. We will update the effective date and provide additional notice in the app when required.',
    ]),
    _PolicySection('10. Contact us', paragraphs: [
      'Nus·Nus is operated by tamilarasan, an independent developer. For privacy questions or requests, email tamilarasanvj@outlook.com.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 36.h),
        children: [
          Text(
            'Nus·Nus',
            style: TextStyle(
              color: AppColors.brass,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 13.sp,
            ),
          ),
          6.verticalSpace,
          Text(
            'Effective date: 21 October 2026',
            style: TextStyle(color: AppColors.slate, fontSize: 12.sp),
          ),
          16.verticalSpace,
          const _PolicyParagraph(
            'This policy explains how Nus·Nus (the “Service”) handles information when you use the Nus·Nus mobile app or web app. The Service is operated by tamilarasan, an independent developer (“we”, “us”, or “our”).',
          ),
          ..._sections.map((section) => _SectionView(section: section)),
          12.verticalSpace,
          const Divider(color: AppColors.line),
          Text(
            'This policy applies to the Nus·Nus app and web app.',
            style: TextStyle(color: AppColors.slate, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _PolicySection {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<_PolicyLink> links;

  const _PolicySection(
    this.title, {
    this.paragraphs = const [],
    this.bullets = const [],
    this.links = const [],
  });
}

class _PolicyLink {
  final String label;
  final String url;

  const _PolicyLink(this.label, this.url);
}

class _SectionView extends StatelessWidget {
  final _PolicySection section;

  const _SectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 17.sp,
            ),
          ),
          6.verticalSpace,
          ...section.paragraphs.map((text) => _PolicyParagraph(text)),
          ...section.bullets.map(
            (text) => Padding(
              padding: EdgeInsets.only(bottom: 7.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style:
                          TextStyle(color: AppColors.brass, fontSize: 14.sp)),
                  Expanded(child: _PolicyParagraph(text)),
                ],
              ),
            ),
          ),
          ...section.links.map(
            (link) => TextButton(
              onPressed: () => launchUrl(
                Uri.parse(link.url),
                mode: LaunchMode.externalApplication,
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                padding: EdgeInsets.symmetric(vertical: 4.h),
              ),
              child: Text(link.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyParagraph extends StatelessWidget {
  final String text;

  const _PolicyParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    final email = 'tamilarasanvj@outlook.com';
    final containsEmail = text.contains(email);
    return Padding(
      padding: EdgeInsets.only(bottom: 9.h),
      child: containsEmail
          ? _ContactParagraph(text: text, email: email)
          : Text(
              text,
              style: TextStyle(
                color: AppColors.inkSoft,
                height: 1.5,
                fontSize: 13.sp,
              ),
            ),
    );
  }
}

class _ContactParagraph extends StatelessWidget {
  final String text;
  final String email;

  const _ContactParagraph({required this.text, required this.email});

  @override
  Widget build(BuildContext context) {
    final parts = text.split(email);
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: AppColors.inkSoft,
          height: 1.5,
          fontSize: 13.sp,
        ),
        children: [
          TextSpan(text: parts.first),
          WidgetSpan(
            child: InkWell(
              onTap: () => launchUrl(Uri(scheme: 'mailto', path: email)),
              child: Text(
                email,
                style: const TextStyle(
                  color: AppColors.ink,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
    );
  }
}
