using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IPortService
{
    Task<IEnumerable<Port>> GetAllPortsAsync();
    Task<Port?> GetPortByIdAsync(int portId);
}