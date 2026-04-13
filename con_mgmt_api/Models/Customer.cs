using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Customers")]
public class Customer
{
    [Key]
    public int CustomerId { get; set; }

    [Required]
    public int UserId { get; set; }

    [Required]
    [MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    [MaxLength(5)]
    public string? MiddleInitial { get; set; }

    [MaxLength(20)]
    public string? ContactNo { get; set; }
}
