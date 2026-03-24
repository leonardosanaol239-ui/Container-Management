using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class StatusService : IStatusService
{
    private readonly ApplicationDbContext _context;

    public StatusService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Status>> GetAllStatusesAsync()
    {
        return await _context.Statuses.ToListAsync();
    }
}