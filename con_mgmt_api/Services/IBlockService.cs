using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IBlockService
{
    Task<IEnumerable<Block>> GetBlocksByYardIdAsync(int yardId);
    Task<Block?> GetBlockByIdAsync(int blockId);
}