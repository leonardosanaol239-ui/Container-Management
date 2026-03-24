using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class RowService : IRowService
{
    private readonly ApplicationDbContext _context;

    public RowService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Row>> GetRowsByBayIdAsync(int bayId)
    {
        return await _context.Rows
            .Where(r => r.BayId == bayId)
            .ToListAsync();
    }

    public async Task<Row?> GetRowByIdAsync(int rowId)
    {
        return await _context.Rows
            .FirstOrDefaultAsync(r => r.RowId == rowId);
    }
}