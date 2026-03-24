using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Bays")]
public class Bay
{
    [Key]
    public int BayId { get; set; }

    [Required]
    [MaxLength(10)]
    public string BayNumber { get; set; } = string.Empty;

    [Required]
    public int BlockId { get; set; }

    // Navigation properties removed to prevent circular references
}
