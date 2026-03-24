using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Trucks")]
public class Truck
{
    [Key]
    public int TruckId { get; set; }

    [Required]
    [MaxLength(50)]
    public string TruckName { get; set; } = string.Empty;
}
