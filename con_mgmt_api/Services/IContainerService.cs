using ContainerManagementApi.DTOs;
using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IContainerService
{
    Task<Container> CreateContainerAsync(CreateContainerDto createDto);
    Task<IEnumerable<Container>> GetContainersByPortIdAsync(int portId);
    Task<IEnumerable<Container>> GetContainersByRowIdAsync(int rowId);
    Task<IEnumerable<Container>> GetContainersByLocationAsync(int? yardId, int? blockId, int? bayId, int? rowId);
    Task<Container?> GetContainerByIdAsync(int containerId);
    Task<Container?> GetContainerByNumberAsync(string containerNumber);
    Task<ContainerLocationHierarchyDto?> GetContainerLocationHierarchyAsync(int containerId);
    Task<Container?> UpdateContainerLocationAsync(int containerId, UpdateContainerLocationDto updateDto);
    Task<Container?> MoveOutContainerAsync(int containerId, MoveOutContainerDto dto);
    Task<IEnumerable<Container>> GetMovedOutContainersAsync(int portId);
}