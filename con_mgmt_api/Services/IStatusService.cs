using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IStatusService
{
    Task<IEnumerable<Status>> GetAllStatusesAsync();
}