using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class BlockService : IBlockService
{
    private readonly ApplicationDbContext _context;

    public BlockService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Block>> GetBlocksByYardIdAsync(int yardId)
    {
        return await _context.Blocks
            .Where(b => b.YardId == yardId)
            .ToListAsync();
    }

    public async Task<Block?> GetBlockByIdAsync(int blockId)
    {
        return await _context.Blocks
            .FirstOrDefaultAsync(b => b.BlockId == blockId);
    }
}