namespace ContainerManagementApi.DTOs;

public class LoginRequestDto
{
    public string UserCode { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public int UserTypeId { get; set; } // 1=Admin, 2=Port Manager, 3=Driver
}

public class LoginResponseDto
{
    public int UserId { get; set; }
    public string UserCode { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public int UserTypeId { get; set; }
    public string Role { get; set; } = string.Empty;
    public int? PortId { get; set; }
    public string? PortDesc { get; set; }
    public int StatusId { get; set; }
}
