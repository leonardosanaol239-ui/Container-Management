using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("Users")]
public class User
{
    [Key]
    [Column("UserId")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(50)]
    public string UserCode { get; set; } = string.Empty;

    [Required]
    public int UserTypeId { get; set; }

    [Required]
    [MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [MaxLength(10)]
    public string MiddleInitial { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Password { get; set; }

    [MaxLength(20)]
    public string ContactNo { get; set; } = string.Empty;

    public DateTime DateCreated { get; set; } = DateTime.UtcNow;

    public int? PortId { get; set; }

    [Required]
    public int StatusId { get; set; } = 3; // 3 = Active
}
