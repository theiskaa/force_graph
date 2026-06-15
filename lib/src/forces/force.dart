import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';

/// A force that adjusts node velocities each tick.
///
/// Ported from d3-force's force contract: [initialize] runs once when the force
/// is registered (and again when the node set changes), and [apply] runs every
/// tick with the simulation's current [alpha].
abstract class Force {
  /// Caches per-node state for the given [nodes]; [random] is the shared
  /// deterministic generator.
  void initialize(List<ForceNode> nodes, Lcg random);

  /// Applies the force for one tick at the given [alpha] (simulation heat).
  void apply(double alpha);
}
