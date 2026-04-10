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

    public async Task UpdateYardImageAsync(int yardId, string imagePath)
    {
        var yard = await _context.Yards.FindAsync(yardId);
        if (yard == null) return;
        yard.ImagePath = imagePath;
        await _context.SaveChangesAsync();
    }

    public async Task<Yard> CreateYardAsync(int portId, double yardWidth, double yardHeight)
    {
        var nextNumber = await _context.Yards
            .Where(y => y.PortId == portId)
            .MaxAsync(y => (int?)y.YardNumber) ?? 0;
        var yard = new Yard
        {
            PortId = portId,
            YardNumber = nextNumber + 1,
            YardWidth = yardWidth,
            YardHeight = yardHeight,
        };
        _context.Yards.Add(yard);
        await _context.SaveChangesAsync();
        return yard;
    }
}