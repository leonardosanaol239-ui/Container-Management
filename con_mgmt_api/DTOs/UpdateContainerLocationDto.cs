using System.ComponentModel.DataAnnotations;

namespace ContainerManagementApi.DTOs;

public class UpdateContainerLocationDto
{
    public int? YardId { get; set; }
    public int? BlockId { get; set; }
    public int? BayId { get; set; }
    public int? RowId { get; set; }

    [Range(1, 5)]
    public int? Tier { get; set; }
}