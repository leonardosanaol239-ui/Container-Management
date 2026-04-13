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

    /// <summary>
    /// Primary port (kept for backward compatibility)
    /// </summary>
    public int? PortId { get; set; }

    /// <summary>
    /// Comma-separated list of assigned port IDs e.g. "1,3,7"
    /// Used for Port Managers who can manage multiple ports.
    /// </summary>
    [MaxLength(500)]
    [Column("PortIds")]
    public string? PortIds { get; set; }

    [Required]
    public int StatusId { get; set; } = 3; // 3 = Active

    // ── Helpers ──────────────────────────────────────────────────────────────

    /// <summary>Parses PortIds string into a list of ints.</summary>
    [NotMapped]
    public List<int> AssignedPortIds =>
        string.IsNullOrWhiteSpace(PortIds)
            ? (PortId.HasValue ? new List<int> { PortId.Value } : new List<int>())
            : PortIds.Split(',', StringSplitOptions.RemoveEmptyEntries)
                     .Select(s => int.TryParse(s.Trim(), out var id) ? id : 0)
                     .Where(id => id > 0)
                     .ToList();

    /// <summary>Sets PortIds from a list and keeps PortId in sync with the first entry.</summary>
    public void SetPortIds(List<int> ids)
    {
        if (ids == null || ids.Count == 0)
        {
            PortIds = null;
            PortId = null;
        }
        else
        {
            PortIds = string.Join(",", ids.Distinct());
            PortId = ids[0]; // keep first for backward compat
        }
    }
}
