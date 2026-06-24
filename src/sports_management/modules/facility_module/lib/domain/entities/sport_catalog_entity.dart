import 'package:server_module/server_module.dart';

class SportCatalogEntity extends SportEntity {
  final String? description;
  final int? teamSize;
  final bool active;

  const SportCatalogEntity({
    required super.id,
    super.name,
    super.iconUrl,
    this.description,
    this.teamSize,
    this.active = true,
  });

  @override
  List<Object?> get props => [id, name, iconUrl, description, teamSize, active];
}
