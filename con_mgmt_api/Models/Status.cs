using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Status")]
public class Status
{
    [Key]
    public int StatusId { get; set; }

    [Required]
    [MaxLength(50)]
    public string StatusDesc { get; set; } = string.Empty;

    // Navigation properties
    public ICollection<Container> Containers { get; set; } = new List<Container>();
}
