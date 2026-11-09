import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/models/system_config_model.dart';
import '../../../../data/repositories/admin_repository_impl.dart';
import '../../../../domain/repositories/admin_repository.dart';

part 'config_event.dart';
part 'config_state.dart';

class ConfigBloc extends Bloc<ConfigEvent, ConfigState> {
  final AdminRepository adminRepository;

  ConfigBloc({AdminRepository? adminRepository})
      : adminRepository = adminRepository ?? AdminRepositoryImpl(),
        super(const ConfigInitial()) {
    on<LoadConfigEvent>(_onLoadConfig);
    on<UpdateConfigEvent>(_onUpdateConfig);
  }

  Future<void> _onLoadConfig(
    LoadConfigEvent event,
    Emitter<ConfigState> emit,
  ) async {
    emit(const ConfigLoading());
    try {
      final config = await adminRepository.getConfig();
      emit(ConfigLoaded(config));
    } catch (e) {
      emit(ConfigError(e.toString()));
    }
  }

  Future<void> _onUpdateConfig(
    UpdateConfigEvent event,
    Emitter<ConfigState> emit,
  ) async {
    SystemConfigModel? previousConfig;
    if (state is ConfigLoaded) {
      previousConfig = (state as ConfigLoaded).config;
    } else if (state is ConfigUpdateSuccess) {
      previousConfig = (state as ConfigUpdateSuccess).config;
    } else if (state is ConfigUpdating) {
      previousConfig = (state as ConfigUpdating).currentConfig;
    }

    if (previousConfig != null) {
      emit(ConfigUpdating(previousConfig));
    } else {
      emit(const ConfigLoading());
    }

    try {
      await adminRepository.saveConfig(event.configMap);
      final updatedConfig = await adminRepository.getConfig();
      emit(ConfigUpdateSuccess(updatedConfig));
    } catch (e) {
      emit(ConfigError(e.toString(), fallbackConfig: previousConfig));
    }
  }
}
