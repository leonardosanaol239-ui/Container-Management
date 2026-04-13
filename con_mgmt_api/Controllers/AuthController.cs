using BCrypt.Net;
using ContainerManagementApi.Data;
using ContainerManagementApi.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private static readonly Dictionary<int, string> _typeIdToRole = new()
    {
        { 1, "Admin" },
        { 2, "Port Manager" },
        { 3, "Driver" },
    };

    private readonly ApplicationDbContext _context;

    public AuthController(ApplicationDbContext context)
    {
        _context = context;
    }

    // POST api/Auth/login
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.UserCode) || string.IsNullOrWhiteSpace(dto.Password))
            return BadRequest(new { message = "User code and password are required." });

        // Find user by code (case-insensitive)
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.UserCode.ToLower() == dto.UserCode.Trim().ToLower());

        // User not found
        if (user == null)
            return Unauthorized(new { message = "Invalid user code or password." });

        // Deleted user cannot log in
        if (user.StatusId == 5)
            return Unauthorized(new { message = "This account has been removed. Please contact your administrator." });

        // Inactive user cannot log in
        if (user.StatusId == 4)
            return Unauthorized(new { message = "This account is inactive. Please contact your administrator." });

        // Role mismatch — selected role must match the user's actual role
        if (user.UserTypeId != dto.UserTypeId)
            return Unauthorized(new { message = "The selected role does not match this user code." });

        // Verify password (BCrypt)
        bool passwordValid = false;
        if (!string.IsNullOrEmpty(user.Password))
        {
            try { passwordValid = BCrypt.Net.BCrypt.Verify(dto.Password, user.Password); }
            catch { passwordValid = false; }
        }

        if (!passwordValid)
            return Unauthorized(new { message = "Invalid user code or password." });

        // Resolve port name
        string? portDesc = null;
        if (user.PortId.HasValue)
        {
            var port = await _context.Ports.FindAsync(user.PortId.Value);
            portDesc = port?.PortDesc;
        }

        var role = _typeIdToRole.TryGetValue(user.UserTypeId, out var r) ? r : "Driver";
        var mi = string.IsNullOrWhiteSpace(user.MiddleInitial) ? "" : $" {user.MiddleInitial.Trim().TrimEnd('.')}.";
        var fullName = $"{user.FirstName}{mi} {user.LastName}".Trim();

        return Ok(new LoginResponseDto
        {
            UserId    = user.UserId,
            UserCode  = user.UserCode,
            FirstName = user.FirstName,
            LastName  = user.LastName,
            FullName  = fullName,
            UserTypeId = user.UserTypeId,
            Role      = role,
            PortId    = user.PortId,
            PortDesc  = portDesc,
            StatusId  = user.StatusId,
        });
    }
}
