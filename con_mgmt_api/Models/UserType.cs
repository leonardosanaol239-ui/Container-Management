using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ContainerManagementApi.Models;

[Table("UserTypes")]
public class UserType
{
    [Key]
    [Column("UserTypeId")]
    public int UserTypeId { get; set; }

    [Required]
    [MaxLength(50)]
    public string UserTypeDesc { get; set; } = string.Empty;
}
