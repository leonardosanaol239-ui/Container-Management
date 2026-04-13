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

        // Collect all unique port IDs across all users
        var allPortIds = users
            .SelectMany(u => u.AssignedPortIds)
            .Distinct()
            .ToList();

        var ports = await _context.Ports
            .Where(p => allPortIds.Contains(p.PortId))
            .ToDictionaryAsync(p => p.PortId, p => p.PortDesc);

        return users.Select(u => ToDto(u, ports));
    }

    public async Task<UserDto?> GetUserByIdAsync(int userId)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null) return null;

        var portIds = user.AssignedPortIds;
        var ports = await _context.Ports
            .Where(p => portIds.Contains(p.PortId))
            .ToDictionaryAsync(p => p.PortId, p => p.PortDesc);

        return ToDto(user, ports);
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
            Password      = string.IsNullOrWhiteSpace(dto.Password)
                                ? null
                                : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
            ContactNo     = dto.ContactNo?.Trim() ?? string.Empty,
            StatusId      = dto.StatusId,
            DateCreated   = DateTime.UtcNow,
        };

        // Handle port assignment
        var portIds = dto.PortIds?.Where(id => id > 0).Distinct().ToList()
                      ?? (dto.PortId.HasValue ? new List<int> { dto.PortId.Value } : new List<int>());
        user.SetPortIds(portIds);

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return (await GetUserByIdAsync(user.UserId))!;
    }

    public async Task<UserDto?> UpdateUserAsync(int userId, SaveUserDto dto)
    {
        var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserId == userId);
        if (user == null) return null;

        // Enforce unique UserCode (excluding this user)
        var codeTaken = await _context.Users
            .AnyAsync(u => u.UserCode.ToLower() == dto.UserCode.Trim().ToLower() && u.UserId != userId);
        if (codeTaken)
            throw new InvalidOperationException($"User code '{dto.UserCode.Trim()}' is already taken.");

        var portIds = dto.PortIds?.Where(id => id > 0).Distinct().ToList()
                      ?? (dto.PortId.HasValue ? new List<int> { dto.PortId.Value } : new List<int>());

        var updated = new User
        {
            UserId        = userId,
            UserCode      = dto.UserCode.Trim(),
            UserTypeId    = dto.UserTypeId,
            FirstName     = dto.FirstName.Trim(),
            MiddleInitial = dto.MiddleInitial?.Trim() ?? string.Empty,
            LastName      = dto.LastName.Trim(),
            ContactNo     = dto.ContactNo?.Trim() ?? string.Empty,
            StatusId      = dto.StatusId,
            DateCreated   = user.DateCreated,
            Password      = string.IsNullOrWhiteSpace(dto.Password)
                                ? user.Password
                                : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
        };
        updated.SetPortIds(portIds);

        _context.Users.Update(updated);
        await _context.SaveChangesAsync();

        return await GetUserByIdAsync(userId);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static UserDto ToDto(User u, Dictionary<int, string> ports)
    {
        var assignedIds = u.AssignedPortIds;
        var assignedDescs = assignedIds
            .Where(id => ports.ContainsKey(id))
            .Select(id => ports[id])
            .ToList();

        return new UserDto
        {
            UserId        = u.UserId,
            UserCode      = u.UserCode,
            UserTypeId    = u.UserTypeId,
            FirstName     = u.FirstName,
            MiddleInitial = u.MiddleInitial,
            LastName      = u.LastName,
            ContactNo     = u.ContactNo,
            DateCreated   = u.DateCreated,
            PortId        = assignedIds.FirstOrDefault() == 0 ? null : assignedIds.FirstOrDefault(),
            PortDesc      = assignedDescs.FirstOrDefault(),
            PortIds       = assignedIds,
            PortDescs     = assignedDescs,
            StatusId      = u.StatusId,
        };
    }
}
