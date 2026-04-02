class CountryOption {
  const CountryOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

const supportedCountryOptions = <CountryOption>[
  CountryOption(code: 'AU', name: 'Australia'),
  CountryOption(code: 'BH', name: 'Bahrain'),
  CountryOption(code: 'BD', name: 'Bangladesh'),
  CountryOption(code: 'CA', name: 'Canada'),
  CountryOption(code: 'EG', name: 'Egypt'),
  CountryOption(code: 'FR', name: 'France'),
  CountryOption(code: 'DE', name: 'Germany'),
  CountryOption(code: 'IN', name: 'India'),
  CountryOption(code: 'ID', name: 'Indonesia'),
  CountryOption(code: 'IQ', name: 'Iraq'),
  CountryOption(code: 'IE', name: 'Ireland'),
  CountryOption(code: 'IT', name: 'Italy'),
  CountryOption(code: 'JO', name: 'Jordan'),
  CountryOption(code: 'KW', name: 'Kuwait'),
  CountryOption(code: 'LB', name: 'Lebanon'),
  CountryOption(code: 'MY', name: 'Malaysia'),
  CountryOption(code: 'NL', name: 'Netherlands'),
  CountryOption(code: 'OM', name: 'Oman'),
  CountryOption(code: 'PK', name: 'Pakistan'),
  CountryOption(code: 'PH', name: 'Philippines'),
  CountryOption(code: 'QA', name: 'Qatar'),
  CountryOption(code: 'SA', name: 'Saudi Arabia'),
  CountryOption(code: 'SG', name: 'Singapore'),
  CountryOption(code: 'ZA', name: 'South Africa'),
  CountryOption(code: 'ES', name: 'Spain'),
  CountryOption(code: 'LK', name: 'Sri Lanka'),
  CountryOption(code: 'TR', name: 'Turkey'),
  CountryOption(code: 'AE', name: 'United Arab Emirates'),
  CountryOption(code: 'GB', name: 'United Kingdom'),
  CountryOption(code: 'US', name: 'United States'),
];

bool isSupportedCountryCode(String? code) {
  if (code == null || code.trim().isEmpty) {
    return false;
  }
  final normalized = code.trim().toUpperCase();
  return supportedCountryOptions.any((item) => item.code == normalized);
}

CountryOption? findCountryOption(String? code) {
  if (code == null || code.trim().isEmpty) {
    return null;
  }
  final normalized = code.trim().toUpperCase();
  for (final item in supportedCountryOptions) {
    if (item.code == normalized) {
      return item;
    }
  }
  return null;
}
