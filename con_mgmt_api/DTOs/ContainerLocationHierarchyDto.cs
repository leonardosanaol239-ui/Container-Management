namespace ContainerManagementApi.DTOs;

public class ContainerLocationHierarchyDto
{
    public int ContainerId { get; set; }
    public string ContainerNumber { get; set; } = string.Empty;
    public string PortDesc { get; set; } = string.Empty;
    public int? YardNumber { get; set; }
    public string? BlockDesc { get; set; }
    public string? BayNumber { get; set; }
    public int? RowNumber { get; set; }
    public int? SlotNumber { get; set; }
    public int? Tier { get; set; }
}