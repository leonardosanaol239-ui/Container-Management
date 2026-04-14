using System.ComponentModel.DataAnnotations;

namespace ContainerManagementApi.DTOs;

public class CreateContainerDto
{
    [Required]
    public int StatusId { get; set; }

    public string? Type { get; set; }

    public string? ContainerDesc { get; set; }

    [Required]
    public int CurrentPortId { get; set; }

    public int? ContainerSizeId { get; set; }
    public int? CustomerId { get; set; }
}
