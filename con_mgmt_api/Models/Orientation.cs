using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Orientations")]
public class Orientation
{
    [Key]
    public int OrientationId { get; set; }

    [Required]
    [MaxLength(20)]
    public string OrientationDesc { get; set; } = string.Empty;
}
