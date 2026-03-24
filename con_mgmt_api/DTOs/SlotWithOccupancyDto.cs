namespace ContainerManagementApi.DTOs;

public class SlotWithOccupancyDto
{
    public int SlotId { get; set; }
    public int RowId { get; set; }
    public int SlotNumber { get; set; }
    public int MaxTier { get; set; }
    public int? SizeId { get; set; }
    public int? OrientationId { get; set; }
    public int MaxStack { get; set; }
    public bool IsDeleted { get; set; }
    public double? PosX { get; set; }
    public double? PosY { get; set; }
    public int ContainerCount { get; set; }
    public List<int> OccupiedTiers { get; set; } = new List<int>();
}
