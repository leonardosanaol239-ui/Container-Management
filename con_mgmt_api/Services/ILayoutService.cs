using ContainerManagementApi.Models;

namespace ContainerManagementApi.Services;

public record CreateBlockRequest(
    int YardId,
    int PortId,
    string BlockName,
    int NumBays,
    int NumRows,
    int OrientationId,
    int SizeId,
    int MaxStack,
    double PosX,
    double PosY
);

public record UpdateBlockPositionRequest(double PosX, double PosY);
public record UpdateBlockRotationRequest(double Rotation);

public record UpdateSlotRequest(int? SizeId, int? OrientationId, int? MaxStack);

public interface ILayoutService
{
    Task<Block> CreateBlockAsync(CreateBlockRequest req);
    Task<Block?> UpdateBlockPositionAsync(int blockId, double posX, double posY);
    Task<Block?> UpdateBlockRotationAsync(int blockId, double rotation);
    Task<bool> DeleteBlockAsync(int blockId);
    Task<object> GetBlockContainersDebugAsync(int blockId);
    Task<Block?> AddBayAsync(int blockId);
    Task<bool> RemoveBayAsync(int blockId);
    Task<Row?> UpdateRowAsync(int rowId, UpdateSlotRequest req);
    Task<bool> DeleteRowAsync(int rowId);
    Task<bool> AddRowAsync(int blockId);
    Task<bool> RemoveRowAsync(int blockId);
    Task<IEnumerable<Size>> GetSizesAsync();
    Task<IEnumerable<Orientation>> GetOrientationsAsync();
}
