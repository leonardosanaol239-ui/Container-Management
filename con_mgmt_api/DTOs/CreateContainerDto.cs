using System.ComponentModel.DataAnnotations;

namespace ContainerManagementApi.DTOs;

public class CreateContainerDto
{
    [Required]
    public int StatusId { get; set; }

    /// <summary>User-supplied container number (e.g. TEMU1234567).
    /// If omitted, the API auto-generates CON-{n}.</summary>
    public string? ContainerNumber { get; set; }

    public string? Type { get; set; }

    public string? ContainerDesc { get; set; }

    [Required]
    public int CurrentPortId { get; set; }

    public int? ContainerSizeId  { get; set; }
    public int? CustomerId       { get; set; }

    // ── Extended fields ──────────────────────────────────────────────────────
    public int?    ContainerStatusId { get; set; }
    public int?    ContainerTypeId   { get; set; }
    public int?    ContainerBoundId  { get; set; }
    public string? Remarks           { get; set; }
    public int?    CreateUserId      { get; set; }
}
