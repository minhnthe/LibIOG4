part of 'checkin_bloc.dart';

abstract class CheckinState extends Equatable {
  const CheckinState();

  @override
  List<Object> get props => [];
}

class CheckinInitial extends CheckinState {}
