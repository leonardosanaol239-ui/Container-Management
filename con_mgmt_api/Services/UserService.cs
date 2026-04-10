using BCrypt.Net;
using ContainerManagementApi.Data;
using ContainerManagementApi.DTOs;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class UserService : IUserService
{
    private readonly ApplicationDbContext _context;

    public UserService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<UserDto>> GetAllUsersAsync()
    {
        var users = await _context.Users.ToListAsync();
        var portIds = users.Where(u => u.PortId.HasValue).Select(u => u.PortId!.Value).Distinct().ToList();
        var ports = await _context.Ports
            .Where(p => portIds.Contains(p.PortId))
            .ToDictionaryAsync(p => p.PortId, p => p.PortDesc);

        return users.Select(u => ToDto(u, ports));
    }

    public async Task<UserDto?> GetUserByIdAsync(int userId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return null;

        string? portDesc = null;
        if (user.PortId.HasValue)
        {
            var port = await _context.Ports.FindAsync(user.PortId.Value);
            portDesc = port?.PortDesc;
        }

        return ToDto(user, user.PortId.HasValue && portDesc != null
            ? new Dictionary<int, string> { { user.PortId.Value, portDesc } }
            : new Dictionary<int, string>());
    }

    public async Task<UserDto> CreateUserAsync(SaveUserDto dto)
    {
        // Enforce unique UserCode
        var exists = await _context.Users
            .AnyAsync(u => u.UserCode.ToLower() == dto.UserCode.Trim().ToLower());
        if (exists)
            throw new InvalidOperationException($"User code '{dto.UserCode.Trim()}' is already taken.");

        var user = new User
        {
            UserCode      = dto.UserCode.Trim(),
            UserTypeId    = dto.UserTypeId,
            FirstName     = dto.FirstName.Trim(),
            MiddleInitial = dto.MiddleInitial?.Trim() ?? string.Empty,
            LastName      = dto.LastName.Trim(),
            // Hash the password with BCrypt (work factor 12)
            Password      = string.IsNullOrWhiteSpace(dto.Password)
                                ? null
                                : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
            ContactNo     = dto.ContactNo?.Trim() ?? string.Empty,
            PortId        = dto.PortId,
            StatusId      = dto.StatusId,
            DateCreated   = DateTime.UtcNow,
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return (await GetUserByIdAsync(user.UserId))!;
    }

    public async Task<UserDto?> UpdateUserAsync(int userId, SaveUserDto dto)
    {
        var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return null;

        // Enforce unique UserCode (excluding this user's own current code)
        var codeTaken = await _context.Users
            .AnyAsync(u => u.UserCode.ToLower() == dto.UserCode.Trim().ToLower() && u.UserId != userId);
        if (codeTaken)
            throw new InvalidOperationException($"User code '{dto.UserCode.Trim()}' is already taken.");

        var updated = new User
        {
            UserId        = userId,
            UserCode      = dto.UserCode.Trim(),
            UserTypeId    = dto.UserTypeId,
            FirstName     = dto.FirstName.Trim(),
            MiddleInitial = dto.MiddleInitial?.Trim() ?? string.Empty,
            LastName      = dto.LastName.Trim(),
            ContactNo     = dto.ContactNo?.Trim() ?? string.Empty,
            PortId        = dto.PortId,
            StatusId      = dto.StatusId,
            DateCreated   = user.DateCreated,
            // Keep existing hash unless a new password was provided
            Password      = string.IsNullOrWhiteSpace(dto.Password)
                                ? user.Password
                                : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
        };

        _context.Users.Update(updated);
        await _context.SaveChangesAsync();

        return await GetUserByIdAsync(userId);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static UserDto ToDto(User u, Dictionary<int, string> ports) => new()
    {
        UserId        = u.UserId,
        UserCode      = u.UserCode,
        UserTypeId    = u.UserTypeId,
        FirstName     = u.FirstName,
        MiddleInitial = u.MiddleInitial,
        LastName      = u.LastName,
        ContactNo     = u.ContactNo,
        DateCreated   = u.DateCreated,
        PortId        = u.PortId,
        PortDesc      = u.PortId.HasValue && ports.TryGetValue(u.PortId.Value, out var desc) ? desc : null,
        StatusId      = u.StatusId,
    };
}
