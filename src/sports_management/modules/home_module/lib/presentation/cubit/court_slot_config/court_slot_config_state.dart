import 'package:equatable/equatable.dart';
import 'package:booking_module/booking_module.dart';

abstract class CourtSlotConfigState extends Equatable {
  const CourtSlotConfigState();

  @override
  List<Object?> get props => [];
}

class CourtSlotConfigInitial extends CourtSlotConfigState {}

class CourtSlotConfigLoading extends CourtSlotConfigState {}

class CourtSlotConfigLoaded extends CourtSlotConfigState {
  final SlotConfigEntity config;

  const CourtSlotConfigLoaded(this.config);

  @override
  List<Object?> get props => [config];
}

class CourtSlotConfigSuccess extends CourtSlotConfigState {
  final String message;

  const CourtSlotConfigSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CourtSlotConfigError extends CourtSlotConfigState {
  final String message;

  const CourtSlotConfigError(this.message);

  @override
  List<Object?> get props => [message];
}
