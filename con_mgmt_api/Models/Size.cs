using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Sizes")]
public class Size
{
    [Key]
    public int SizeId { get; set; }

    [Required]
    [MaxLength(20)]
    public string SizeDesc { get; set; } = string.Empty;
}
