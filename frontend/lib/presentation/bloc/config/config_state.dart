part of 'config_bloc.dart';

abstract class ConfigState extends Equatable {
  const ConfigState();

  @override
  List<Object?> get props => [];
}

class ConfigInitial extends ConfigState {
  const ConfigInitial();
}

class ConfigLoading extends ConfigState {
  const ConfigLoading();
}

class ConfigLoaded extends ConfigState {
  final SystemConfigModel config;

  const ConfigLoaded(this.config);

  @override
  List<Object?> get props => [config];
}

class ConfigUpdating extends ConfigState {
  final SystemConfigModel currentConfig;

  const ConfigUpdating(this.currentConfig);

  @override
  List<Object?> get props => [currentConfig];
}

class ConfigUpdateSuccess extends ConfigState {
  final SystemConfigModel config;
  final String message;

  const ConfigUpdateSuccess(this.config, {this.message = 'Cập nhật cấu hình thành công'});

  @override
  List<Object?> get props => [config, message];
}

class ConfigError extends ConfigState {
  final String message;
  final SystemConfigModel? fallbackConfig;

  const ConfigError(this.message, {this.fallbackConfig});

  @override
  List<Object?> get props => [message, fallbackConfig];
}
