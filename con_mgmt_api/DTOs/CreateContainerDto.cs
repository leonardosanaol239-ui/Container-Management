using System.ComponentModel.DataAnnotations;

namespace ContainerManagementApi.DTOs;

public class CreateContainerDto
{
    [Required]
    public int StatusId { get; set; }

    [Required]
    public string Type { get; set; } = string.Empty;

    public string? ContainerDesc { get; set; }

    [Required]
    public int CurrentPortId { get; set; }
}
