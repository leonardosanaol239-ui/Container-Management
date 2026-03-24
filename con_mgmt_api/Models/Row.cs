using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Rows")]
public class Row
{
    [Key]
    public int RowId { get; set; }

    [Required]
    public int RowNumber { get; set; }

    [Required]
    public int BayId { get; set; }

    // Layout columns (merged from Slots — each row IS a slot)
    public int? SizeId { get; set; }
    public int? OrientationId { get; set; }
    public int MaxStack { get; set; } = 5;
    public bool IsDeleted { get; set; } = false;
    public double? PosX { get; set; }
    public double? PosY { get; set; }
}
