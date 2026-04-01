using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IYardService
{
    Task<IEnumerable<Yard>> GetYardsByPortIdAsync(int portId);
    Task<Yard?> GetYardByIdAsync(int yardId);
    Task UpdateYardImageAsync(int yardId, string imagePath);
}