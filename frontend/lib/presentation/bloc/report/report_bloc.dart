import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/report_data_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

export 'report_event.dart';
export 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final AdminRepository adminRepository;

  ReportBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(const ReportInitial()) {
    on<FetchReportEvent>(_onFetchReport);
    on<ExportCsvEvent>(_onExportCsv);
  }

  ReportDataModel? get _currentData {
    final s = state;
    if (s is ReportLoaded) return s.data;
    if (s is ReportExportSuccess) return s.data;
    if (s is ReportError) return s.fallbackData;
    return null;
  }

  String get _currentGroupBy {
    final s = state;
    if (s is ReportLoaded) return s.currentGroupBy;
    if (s is ReportExportSuccess) return s.currentGroupBy;
    if (s is ReportError) return s.currentGroupBy;
    if (s is ReportLoading) return s.groupBy;
    return 'hour';
  }

  Future<void> _onFetchReport(
    FetchReportEvent event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportLoading(groupBy: event.groupBy));

    try {
      final report = await adminRepository.getReport(
        groupBy: event.groupBy,
        from: event.from,
        to: event.to,
      );
      emit(ReportLoaded(report, currentGroupBy: event.groupBy));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(ReportError(
        message,
        fallbackData: _currentData,
        currentGroupBy: event.groupBy,
      ));
    }
  }

  Future<void> _onExportCsv(
    ExportCsvEvent event,
    Emitter<ReportState> emit,
  ) async {
    final currentData = _currentData ?? ReportDataModel.empty();
    final groupBy = _currentGroupBy;

    if (state is ReportLoaded) {
      emit((state as ReportLoaded).copyWith(isExporting: true));
    }

    try {
      final csv = await adminRepository.exportCsv(
        from: event.from,
        to: event.to,
      );
      final fileName = 'library_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      emit(ReportExportSuccess(
        csvContent: csv,
        fileName: fileName,
        data: currentData,
        currentGroupBy: groupBy,
      ));
      emit(ReportLoaded(currentData, currentGroupBy: groupBy));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      emit(ReportError(
        'Không thể xuất file CSV: $message',
        fallbackData: currentData,
        currentGroupBy: groupBy,
      ));
    }
  }
}
