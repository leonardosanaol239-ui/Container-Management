namespace ContainerManagementApi.DTOs;

public class MoveOutContainerDto
{
    public int TruckId { get; set; }
    public string BoundTo { get; set; } = string.Empty;
}
