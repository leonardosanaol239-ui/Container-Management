using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IRowService
{
    Task<IEnumerable<Row>> GetRowsByBayIdAsync(int bayId);
    Task<Row?> GetRowByIdAsync(int rowId);
}