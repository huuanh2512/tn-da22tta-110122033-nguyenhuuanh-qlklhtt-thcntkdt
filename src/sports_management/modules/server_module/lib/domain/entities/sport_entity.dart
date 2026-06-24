import 'package:equatable/equatable.dart';

class SportEntity extends Equatable {
  final String id;
  final String? name;
  final String? iconUrl;

  const SportEntity({
    required this.id,
    this.name,
    this.iconUrl,
  });

  @override
  List<Object?> get props => [id, name, iconUrl];
}