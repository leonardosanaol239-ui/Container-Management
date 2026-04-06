using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Blocks")]
public class Block
{
    [Key]
    public int BlockId { get; set; }

    [Required]
    public int BlockNumber { get; set; }

    [MaxLength(100)]
    public string? BlockDesc { get; set; }

    [MaxLength(100)]
    public string? BlockName { get; set; }

    [Required]
    public int YardId { get; set; }

    [Required]
    [Column("PortId")]
    public int PortId { get; set; }

    // Dynamic layout columns
    public int? OrientationId { get; set; }
    public int? SizeId { get; set; }
    public double? PosX { get; set; }
    public double? PosY { get; set; }
    public double Rotation { get; set; } = 0;
}
