class BusinessDataSummary {
  final String periodLabel;
  final int activeStudentCount;
  final int inactiveStudentCount;
  final double periodRevenue;
  final Map<String, int> attendanceStatusDistribution;
  final List<BusinessContributorSnapshot> topContributors;
  final List<String> riskStudentNames;
  final List<String> insightMessages;

  const BusinessDataSummary({
    required this.periodLabel,
    required this.activeStudentCount,
    required this.inactiveStudentCount,
    required this.periodRevenue,
    this.attendanceStatusDistribution = const <String, int>{},
    this.topContributors = const <BusinessContributorSnapshot>[],
    this.riskStudentNames = const <String>[],
    this.insightMessages = const <String>[],
  });
}

class BusinessContributorSnapshot {
  final String name;
  final double totalFee;
  final int attendanceCount;

  const BusinessContributorSnapshot({
    required this.name,
    required this.totalFee,
    required this.attendanceCount,
  });
}
