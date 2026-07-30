class CountryCode {
  final String name;
  final String dialCode;
  final String flagEmoji;
  final String code;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
    required this.code,
  });

  static const List<CountryCode> all = [
    CountryCode(name: 'United Arab Emirates', dialCode: '+971', flagEmoji: '🇦🇪', code: 'AE'),
    CountryCode(name: 'India', dialCode: '+91', flagEmoji: '🇮🇳', code: 'IN'),
    CountryCode(name: 'Saudi Arabia', dialCode: '+966', flagEmoji: '🇸🇦', code: 'SA'),
    CountryCode(name: 'Qatar', dialCode: '+974', flagEmoji: '🇶🇦', code: 'QA'),
    CountryCode(name: 'Kuwait', dialCode: '+965', flagEmoji: '🇰🇼', code: 'KW'),
    CountryCode(name: 'Oman', dialCode: '+968', flagEmoji: '🇴🇲', code: 'OM'),
    CountryCode(name: 'Bahrain', dialCode: '+973', flagEmoji: '🇧🇭', code: 'BH'),
    CountryCode(name: 'United States', dialCode: '+1', flagEmoji: '🇺🇸', code: 'US'),
    CountryCode(name: 'United Kingdom', dialCode: '+44', flagEmoji: '🇬🇧', code: 'GB'),
    CountryCode(name: 'Canada', dialCode: '+1', flagEmoji: '🇨🇦', code: 'CA'),
    CountryCode(name: 'Australia', dialCode: '+61', flagEmoji: '🇦🇺', code: 'AU'),
    CountryCode(name: 'Singapore', dialCode: '+65', flagEmoji: '🇸🇬', code: 'SG'),
    CountryCode(name: 'Germany', dialCode: '+49', flagEmoji: '🇩🇪', code: 'DE'),
    CountryCode(name: 'France', dialCode: '+33', flagEmoji: '🇫🇷', code: 'FR'),
    CountryCode(name: 'Italy', dialCode: '+39', flagEmoji: '🇮🇹', code: 'IT'),
    CountryCode(name: 'Spain', dialCode: '+34', flagEmoji: '🇪🇸', code: 'ES'),
    CountryCode(name: 'Malaysia', dialCode: '+60', flagEmoji: '🇲🇾', code: 'MY'),
    CountryCode(name: 'Pakistan', dialCode: '+92', flagEmoji: '🇵🇰', code: 'PK'),
    CountryCode(name: 'Sri Lanka', dialCode: '+94', flagEmoji: '🇱🇰', code: 'LK'),
    CountryCode(name: 'Egypt', dialCode: '+20', flagEmoji: '🇪🇬', code: 'EG'),
    CountryCode(name: 'Philippines', dialCode: '+63', flagEmoji: '🇵🇭', code: 'PH'),
    CountryCode(name: 'Indonesia', dialCode: '+62', flagEmoji: '🇮🇩', code: 'ID'),
    CountryCode(name: 'Vietnam', dialCode: '+84', flagEmoji: '🇻🇳', code: 'VN'),
    CountryCode(name: 'Thailand', dialCode: '+66', flagEmoji: '🇹🇭', code: 'TH'),
  ];
}
