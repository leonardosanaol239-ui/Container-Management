using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public interface IYardService
{
    Task<IEnumerable<Yard>> GetYardsByPortIdAsync(int portId);
    Task<Yard?> GetYardByIdAsync(int yardId);
    Task UpdateYardImageAsync(int yardId, string imagePath);
    Task UpdateYardDimensionsAsync(int yardId, double width, double height);
    Task UpdateYardCapacityAsync(int yardId, int? capacity);
    Task<Yard> CreateYardAsync(int portId, double yardWidth, double yardHeight);
    Task<bool> DeleteYardAsync(int yardId);
}