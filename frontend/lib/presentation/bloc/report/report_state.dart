import 'package:equatable/equatable.dart';
import '../../../../data/models/report_data_model.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {
  const ReportInitial();
}

class ReportLoading extends ReportState {
  final String groupBy;

  const ReportLoading({this.groupBy = 'hour'});

  @override
  List<Object?> get props => [groupBy];
}

class ReportLoaded extends ReportState {
  final ReportDataModel data;
  final String currentGroupBy;
  final bool isExporting;

  const ReportLoaded(
    this.data, {
    this.currentGroupBy = 'hour',
    this.isExporting = false,
  });

  ReportLoaded copyWith({
    ReportDataModel? data,
    String? currentGroupBy,
    bool? isExporting,
  }) {
    return ReportLoaded(
      data ?? this.data,
      currentGroupBy: currentGroupBy ?? this.currentGroupBy,
      isExporting: isExporting ?? this.isExporting,
    );
  }

  @override
  List<Object?> get props => [data, currentGroupBy, isExporting];
}

class ReportExportSuccess extends ReportState {
  final String csvContent;
  final String fileName;
  final ReportDataModel data;
  final String currentGroupBy;

  const ReportExportSuccess({
    required this.csvContent,
    required this.fileName,
    required this.data,
    required this.currentGroupBy,
  });

  @override
  List<Object?> get props => [csvContent, fileName, data, currentGroupBy];
}

class ReportError extends ReportState {
  final String message;
  final ReportDataModel? fallbackData;
  final String currentGroupBy;

  const ReportError(
    this.message, {
    this.fallbackData,
    this.currentGroupBy = 'hour',
  });

  @override
  List<Object?> get props => [message, fallbackData, currentGroupBy];
}
