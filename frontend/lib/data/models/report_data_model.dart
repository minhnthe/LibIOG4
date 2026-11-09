import 'package:equatable/equatable.dart';

class ReportDataModel extends Equatable {
  final List<String> labels;
  final List<int> checkIns;
  final int totalVisits;
  final int avgDuration;

  const ReportDataModel({
    this.labels = const [],
    this.checkIns = const [],
    this.totalVisits = 0,
    this.avgDuration = 0,
  });

  factory ReportDataModel.empty() {
    return const ReportDataModel(
      labels: [],
      checkIns: [],
      totalVisits: 0,
      avgDuration: 0,
    );
  }

  factory ReportDataModel.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] as List<dynamic>? ?? [];
    final rawCheckIns = json['checkIns'] as List<dynamic>? ?? [];

    return ReportDataModel(
      labels: rawLabels.map((e) => e.toString()).toList(),
      checkIns: rawCheckIns.map((e) => int.tryParse(e.toString()) ?? 0).toList(),
      totalVisits: int.tryParse(json['totalVisits']?.toString() ?? '0') ?? 0,
      avgDuration: int.tryParse(json['avgDuration']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'labels': labels,
      'checkIns': checkIns,
      'totalVisits': totalVisits,
      'avgDuration': avgDuration,
    };
  }

  bool get isEmpty => labels.isEmpty || checkIns.isEmpty || totalVisits == 0;
  bool get isNotEmpty => !isEmpty;

  int get maxCheckIns {
    if (checkIns.isEmpty) return 0;
    return checkIns.reduce((a, b) => a > b ? a : b);
  }

  String get peakTimeLabel {
    if (checkIns.isEmpty || labels.isEmpty) return '--';
    int maxVal = -1;
    int maxIdx = 0;
    for (int i = 0; i < checkIns.length; i++) {
      if (checkIns[i] > maxVal) {
        maxVal = checkIns[i];
        maxIdx = i;
      }
    }
    return maxIdx < labels.length ? labels[maxIdx] : '--';
  }

  int get peakCheckIns {
    if (checkIns.isEmpty) return 0;
    return checkIns.reduce((a, b) => a > b ? a : b);
  }

  @override
  List<Object?> get props => [labels, checkIns, totalVisits, avgDuration];
}
