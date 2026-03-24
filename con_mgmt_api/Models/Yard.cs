using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Yards")]
public class Yard
{
    [Key]
    public int YardId { get; set; }

    [Required]
    public int YardNumber { get; set; }

    [Required]
    [Column("PortId")]
    public int PortId { get; set; }

    public double? YardWidth { get; set; }
    public double? YardHeight { get; set; }
}
