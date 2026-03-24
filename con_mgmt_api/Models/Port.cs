using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Ports")]
public class Port
{
    [Key]
    [Column("PortId")]
    public int PortId { get; set; }

    [Required]
    [MaxLength(100)]
    public string PortDesc { get; set; } = string.Empty;

    // Navigation properties removed to prevent circular references
}
