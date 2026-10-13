import 'narration_position.dart';

class ReadingPositionSnapshot {
  const ReadingPositionSnapshot(this.position, this.percentage, this.revision,
      {this.deleted = false, this.narration});
  final String position;
  final double percentage;
  final String revision;
  final bool deleted;
  final NarrationPosition? narration;
}
