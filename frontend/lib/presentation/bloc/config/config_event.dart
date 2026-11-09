part of 'config_bloc.dart';

abstract class ConfigEvent extends Equatable {
  const ConfigEvent();

  @override
  List<Object?> get props => [];
}

class LoadConfigEvent extends ConfigEvent {
  const LoadConfigEvent();
}

class UpdateConfigEvent extends ConfigEvent {
  final Map<String, dynamic> configMap;

  const UpdateConfigEvent(this.configMap);

  @override
  List<Object?> get props => [configMap];
}
