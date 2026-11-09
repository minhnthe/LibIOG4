import 'package:equatable/equatable.dart';

class SystemConfigModel extends Equatable {
  final int maxCapacity;
  final String openTime;
  final String closeTime;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final int warningMinutesBeforeClose;
  final int maxSessionHours;
  final String allowedDays;
  final String? nextOpenTime;
  final String? nextCloseTime;
  final String? effectiveDate;

  const SystemConfigModel({
    required this.maxCapacity,
    required this.openTime,
    required this.closeTime,
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.warningMinutesBeforeClose = 30,
    this.maxSessionHours = 8,
    this.allowedDays = 'Mon,Tue,Wed,Thu,Fri,Sat',
    this.nextOpenTime,
    this.nextCloseTime,
    this.effectiveDate,
  });

  bool get hasPendingOperatingHours =>
      nextOpenTime != null &&
      nextCloseTime != null &&
      effectiveDate != null &&
      effectiveDate!.isNotEmpty;

  factory SystemConfigModel.empty() {
    return const SystemConfigModel(
      maxCapacity: 100,
      openTime: '07:00',
      closeTime: '21:00',
      maintenanceMode: false,
    );
  }

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) {
    return SystemConfigModel(
      maxCapacity: int.tryParse(json['maxCapacity']?.toString() ?? '100') ?? 100,
      openTime: json['openTime']?.toString() ?? '07:00',
      closeTime: json['closeTime']?.toString() ?? '21:00',
      maintenanceMode: json['maintenanceMode'] == true || json['maintenanceMode'] == 'true',
      maintenanceMessage: json['maintenanceMessage']?.toString() ?? '',
      warningMinutesBeforeClose: int.tryParse(json['warningMinutesBeforeClose']?.toString() ?? '30') ?? 30,
      maxSessionHours: int.tryParse(json['maxSessionHours']?.toString() ?? '8') ?? 8,
      allowedDays: json['allowedDays']?.toString() ?? 'Mon,Tue,Wed,Thu,Fri,Sat',
      nextOpenTime: json['nextOpenTime']?.toString() ?? json['NEXT_OPEN_TIME']?.toString(),
      nextCloseTime: json['nextCloseTime']?.toString() ?? json['NEXT_CLOSE_TIME']?.toString(),
      effectiveDate: json['effectiveDate']?.toString() ?? json['OPERATING_HOURS_EFFECTIVE_DATE']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxCapacity': maxCapacity,
      'openTime': openTime,
      'closeTime': closeTime,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'warningMinutesBeforeClose': warningMinutesBeforeClose,
      'maxSessionHours': maxSessionHours,
      'allowedDays': allowedDays,
      if (nextOpenTime != null) 'nextOpenTime': nextOpenTime,
      if (nextCloseTime != null) 'nextCloseTime': nextCloseTime,
      if (effectiveDate != null) 'effectiveDate': effectiveDate,
    };
  }

  SystemConfigModel copyWith({
    int? maxCapacity,
    String? openTime,
    String? closeTime,
    bool? maintenanceMode,
    String? maintenanceMessage,
    int? warningMinutesBeforeClose,
    int? maxSessionHours,
    String? allowedDays,
    String? nextOpenTime,
    String? nextCloseTime,
    String? effectiveDate,
  }) {
    return SystemConfigModel(
      maxCapacity: maxCapacity ?? this.maxCapacity,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      warningMinutesBeforeClose: warningMinutesBeforeClose ?? this.warningMinutesBeforeClose,
      maxSessionHours: maxSessionHours ?? this.maxSessionHours,
      allowedDays: allowedDays ?? this.allowedDays,
      nextOpenTime: nextOpenTime ?? this.nextOpenTime,
      nextCloseTime: nextCloseTime ?? this.nextCloseTime,
      effectiveDate: effectiveDate ?? this.effectiveDate,
    );
  }

  @override
  List<Object?> get props => [
        maxCapacity,
        openTime,
        closeTime,
        maintenanceMode,
        maintenanceMessage,
        warningMinutesBeforeClose,
        maxSessionHours,
        allowedDays,
        nextOpenTime,
        nextCloseTime,
        effectiveDate,
      ];
}
