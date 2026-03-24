using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("LocationStatus")]
public class LocationStatus
{
    [Key]
    public int LocationStatusId { get; set; }

    [Required]
    [MaxLength(50)]
    public string LocationStatusDesc { get; set; } = string.Empty;
}
