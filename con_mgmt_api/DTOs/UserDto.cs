namespace ContainerManagementApi.DTOs;

/// <summary>
/// DTO returned to the client — includes resolved names for portDesc
/// </summary>
public class UserDto
{
    public int UserId { get; set; }
    public string UserCode { get; set; } = string.Empty;
    public int UserTypeId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string MiddleInitial { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string ContactNo { get; set; } = string.Empty;
    public DateTime DateCreated { get; set; }
    public int? PortId { get; set; }
    public string? PortDesc { get; set; }
    public int StatusId { get; set; }
}

/// <summary>
/// DTO received from the client for create / update
/// </summary>
public class SaveUserDto
{
    public string UserCode { get; set; } = string.Empty;
    public int UserTypeId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string MiddleInitial { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Password { get; set; }
    public string ContactNo { get; set; } = string.Empty;
    public int? PortId { get; set; }
    public int StatusId { get; set; } = 3;
}
