using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class BayService : IBayService
{
    private readonly ApplicationDbContext _context;

    public BayService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Bay>> GetBaysByBlockIdAsync(int blockId)
    {
        return await _context.Bays
            .Where(b => b.BlockId == blockId)
            .ToListAsync();
    }

    public async Task<Bay?> GetBayByIdAsync(int bayId)
    {
        return await _context.Bays
            .FirstOrDefaultAsync(b => b.BayId == bayId);
    }
}