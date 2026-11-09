import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class FetchReportEvent extends ReportEvent {
  final String groupBy; // 'hour' | 'day' | 'week'
  final String? from;
  final String? to;

  const FetchReportEvent({
    this.groupBy = 'hour',
    this.from,
    this.to,
  });

  @override
  List<Object?> get props => [groupBy, from, to];
}

class ExportCsvEvent extends ReportEvent {
  final String? from;
  final String? to;

  const ExportCsvEvent({this.from, this.to});

  @override
  List<Object?> get props => [from, to];
}
