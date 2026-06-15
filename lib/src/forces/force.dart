import 'package:force_graph/src/lcg.dart';
import 'package:force_graph/src/models.dart';

abstract class Force {
  void initialize(List<ForceNode> nodes, Lcg random);
  void apply(double alpha);
}
