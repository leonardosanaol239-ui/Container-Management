using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class YardService : IYardService
{
    private readonly ApplicationDbContext _context;

    public YardService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Yard>> GetYardsByPortIdAsync(int portId)
    {
        return await _context.Yards
            .Where(y => y.PortId == portId)
            .ToListAsync();
    }

    public async Task<Yard?> GetYardByIdAsync(int yardId)
    {
        return await _context.Yards
            .FirstOrDefaultAsync(y => y.YardId == yardId);
    }
}