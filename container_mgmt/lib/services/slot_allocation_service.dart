import '../models/yard.dart';
import 'api_service.dart';

/// Represents a vacant slot location
class VacantSlot {
  final int yardId;
  final int blockId;
  final String blockName;
  final int bayId;
  final String bayNumber;
  final int rowId;
  final String rowNumber;
  final int tier;
  final double distanceFromEntrance;

  VacantSlot({
    required this.yardId,
    required this.blockId,
    required this.blockName,
    required this.bayId,
    required this.bayNumber,
    required this.rowId,
    required this.rowNumber,
    required this.tier,
    required this.distanceFromEntrance,
  });

  /// Get human-readable location string
  String get locationString =>
      'Yard $yardId > $blockName > Bay $bayNumber > Row $rowNumber > Tier $tier';
}

/// Service to find the nearest vacant slot to the entrance
class SlotAllocationService {
  final ApiService _api = ApiService();

  /// Find the nearest vacant slot to the entrance for a given container
  /// Entrance is assumed to be at bottom-left corner (0, yardHeight)
  Future<VacantSlot?> findNearestVacantSlot(
    int portId,
    int containerSizeId,
  ) async {
    try {
      // Get all yards for the port
      final yards = await _api.getYards(portId);
      if (yards.isEmpty) return null;

      List<VacantSlot> allVacantSlots = [];

      // Check each yard for vacant slots
      for (final yard in yards) {
        final yardSlots = await _findVacantSlotsInYard(
          yard,
          containerSizeId,
        );
        allVacantSlots.addAll(yardSlots);
      }

      if (allVacantSlots.isEmpty) return null;

      // Sort by distance from entrance and return the nearest
      allVacantSlots.sort((a, b) => a.distanceFromEntrance.compareTo(b.distanceFromEntrance));
      return allVacantSlots.first;
    } catch (e) {
      return null;
    }
  }

  /// Find all vacant slots in a yard that match the container size
  Future<List<VacantSlot>> _findVacantSlotsInYard(
    Yard yard,
    int containerSizeId,
  ) async {
    List<VacantSlot> vacantSlots = [];

    try {
      // Get all blocks in the yard
      final blocks = await _api.getBlocks(yard.yardId);
      
      // Yard dimensions for distance calculation
      final yardWidth = yard.yardWidth ?? 550;
      final yardHeight = yard.yardHeight ?? 238;
      
      // Entrance point (bottom-left corner)
      final entranceX = 0.0;
      final entranceY = yardHeight;

      for (final block in blocks) {
        // Get block position
        final blockX = block.posX ?? 10.0;
        final blockY = block.posY ?? 10.0;

        // Get all bays in the block
        final bays = await _api.getBays(block.blockId);

        for (final bay in bays) {
          // Get all rows in the bay
          final rows = await _api.getRows(bay.bayId);

          for (final row in rows) {
            // Check if row size matches container size
            if (row.sizeId != null && row.sizeId != containerSizeId) {
              continue;
            }

            // Get containers in this row
            final containers = await _api.getContainersByLocation(
              yardId: yard.yardId,
              blockId: block.blockId,
              bayId: bay.bayId,
              rowId: row.rowId,
            );

            final currentTierCount = containers.length;
            final maxStack = row.maxStack ?? 5;

            // If there's space, add as vacant slot
            if (currentTierCount < maxStack) {
              final nextTier = currentTierCount + 1;
              
              // Calculate distance from entrance to this slot
              // Distance = Euclidean distance from entrance to block center
              final distance = _calculateDistance(
                entranceX,
                entranceY,
                blockX,
                blockY,
              );

              vacantSlots.add(VacantSlot(
                yardId: yard.yardId,
                blockId: block.blockId,
                blockName: block.blockDesc ?? 'Block ${block.blockNumber}',
                bayId: bay.bayId,
                bayNumber: bay.bayNumber,
                rowId: row.rowId,
                rowNumber: row.rowNumber.toString(),
                tier: nextTier,
                distanceFromEntrance: distance,
              ));
            }
          }
        }
      }
    } catch (e) {
      // Return empty list on error
    }

    return vacantSlots;
  }

  /// Calculate Euclidean distance between two points
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return (dx * dx + dy * dy); // Return squared distance for comparison
  }
}
