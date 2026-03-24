using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IBayService
{
    Task<IEnumerable<Bay>> GetBaysByBlockIdAsync(int blockId);
    Task<Bay?> GetBayByIdAsync(int bayId);
}