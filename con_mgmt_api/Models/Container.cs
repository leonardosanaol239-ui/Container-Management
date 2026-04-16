using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Containers")]
public class Container
{
    [Key]
    public int ContainerId { get; set; }

    [Required]
    [MaxLength(50)]
    public string ContainerNumber { get; set; } = string.Empty;

    [Required]
    public int StatusId { get; set; }

    [MaxLength(100)]
    public string? Type { get; set; }

    public string? ContainerDesc { get; set; }

    [Required]
    [Column("CurrentPortId")]
    public int CurrentPortId { get; set; }

    public int? YardId { get; set; }
    public int? BlockId { get; set; }
    public int? BayId { get; set; }
    public int? RowId { get; set; }

    [Range(1, 5)]
    public int? Tier { get; set; }

    public int? LocationStatusId { get; set; }
    public int? TruckId { get; set; }

    [MaxLength(255)]
    public string? BoundTo { get; set; }

    // Previous confirmed location (before move request)
    public int? PrevYardId { get; set; }
    public int? PrevBlockId { get; set; }
    public int? PrevBayId { get; set; }
    public int? PrevRowId { get; set; }
    public int? PrevTier { get; set; }

    // Container physical size (references Sizes table)
    public int? ContainerSizeId { get; set; }

    public int? CustomerId { get; set; }

    public DateTime CreatedDate { get; set; } = DateTime.UtcNow;

    // Navigation properties removed to prevent circular references
    // Use separate DTOs or queries when you need related data
}
