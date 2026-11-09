import 'package:equatable/equatable.dart';
import 'present_student_model.dart';

class OccupancyStatsModel extends Equatable {
  final int currentOccupancy;
  final int maxCapacity;
  final int occupancyPercent;
  final List<PresentStudentModel> presentList;
  final int totalVisitsToday;
  final int peakOccupancy;
  final String? peakTime;

  const OccupancyStatsModel({
    required this.currentOccupancy,
    required this.maxCapacity,
    required this.occupancyPercent,
    this.presentList = const [],
    this.totalVisitsToday = 0,
    this.peakOccupancy = 0,
    this.peakTime,
  });

  factory OccupancyStatsModel.empty() {
    return const OccupancyStatsModel(
      currentOccupancy: 0,
      maxCapacity: 100,
      occupancyPercent: 0,
      presentList: [],
    );
  }

  factory OccupancyStatsModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['presentList'] as List<dynamic>? ?? [];
    final parsedList = rawList
        .map((e) => PresentStudentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final current = int.tryParse(json['currentOccupancy']?.toString() ?? '0') ?? 0;
    final max = int.tryParse(json['maxCapacity']?.toString() ?? '100') ?? 100;
    final percent = max > 0 ? ((current / max) * 100).round() : 0;

    return OccupancyStatsModel(
      currentOccupancy: current,
      maxCapacity: max,
      occupancyPercent: int.tryParse(json['occupancyPercent']?.toString() ?? '') ?? percent,
      presentList: parsedList,
      totalVisitsToday: int.tryParse(json['totalVisitsToday']?.toString() ?? '0') ?? 0,
      peakOccupancy: int.tryParse(json['peakOccupancy']?.toString() ?? '0') ?? 0,
      peakTime: json['peakTime']?.toString(),
    );
  }

  OccupancyStatsModel copyWith({
    int? currentOccupancy,
    int? maxCapacity,
    int? occupancyPercent,
    List<PresentStudentModel>? presentList,
    int? totalVisitsToday,
    int? peakOccupancy,
    String? peakTime,
  }) {
    return OccupancyStatsModel(
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      presentList: presentList ?? this.presentList,
      totalVisitsToday: totalVisitsToday ?? this.totalVisitsToday,
      peakOccupancy: peakOccupancy ?? this.peakOccupancy,
      peakTime: peakTime ?? this.peakTime,
    );
  }

  @override
  List<Object?> get props => [
        currentOccupancy,
        maxCapacity,
        occupancyPercent,
        presentList,
        totalVisitsToday,
        peakOccupancy,
        peakTime,
      ];
}
