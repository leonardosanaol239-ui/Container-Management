using ContainerManagementApi.Data;
using ContainerManagementApi.DTOs;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class ContainerService : IContainerService
{
    private readonly ApplicationDbContext _context;

    public ContainerService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Container> CreateContainerAsync(CreateContainerDto createDto)
    {
        // Validate CurrentPortId exists
        var portExists = await _context.Ports.AnyAsync(p => p.PortId == createDto.CurrentPortId);
        if (!portExists)
        {
            throw new ArgumentException("Invalid CurrentPortId");
        }

        // Validate StatusId exists
        var statusExists = await _context.Statuses.AnyAsync(s => s.StatusId == createDto.StatusId);
        if (!statusExists)
        {
            throw new ArgumentException("Invalid StatusId");
        }

        // Generate container number
        var lastContainer = await _context.Containers
            .OrderByDescending(c => c.ContainerId)
            .FirstOrDefaultAsync();
        
        var nextNumber = 1;
        if (lastContainer != null)
        {
            var lastNumberStr = lastContainer.ContainerNumber.Replace("CON-", "");
            if (int.TryParse(lastNumberStr, out var lastNumber))
            {
                nextNumber = lastNumber + 1;
            }
        }

        var container = new Container
        {
            ContainerNumber = $"CON-{nextNumber}",
            StatusId = createDto.StatusId,
            Type = createDto.Type,
            ContainerDesc = createDto.ContainerDesc,
            CurrentPortId = createDto.CurrentPortId,
            CreatedDate = DateTime.UtcNow
        };

        _context.Containers.Add(container);
        await _context.SaveChangesAsync();

        return container;
    }

    public async Task<IEnumerable<Container>> GetContainersByPortIdAsync(int portId)
    {
        return await _context.Containers
            .Where(c => c.CurrentPortId == portId)
            .ToListAsync();
    }

    public async Task<Container?> GetContainerByIdAsync(int containerId)
    {
        return await _context.Containers
            .FirstOrDefaultAsync(c => c.ContainerId == containerId);
    }

    public async Task<Container?> GetContainerByNumberAsync(string containerNumber)
    {
        return await _context.Containers
            .FirstOrDefaultAsync(c => c.ContainerNumber == containerNumber);
    }

    public async Task<ContainerLocationHierarchyDto?> GetContainerLocationHierarchyAsync(int containerId)
    {
        var container = await _context.Containers
            .FirstOrDefaultAsync(c => c.ContainerId == containerId);

        if (container == null) return null;

        // Get related data separately to avoid circular references
        var port = await _context.Ports.FirstOrDefaultAsync(p => p.PortId == container.CurrentPortId);
        var yard = container.YardId.HasValue ? await _context.Yards.FirstOrDefaultAsync(y => y.YardId == container.YardId) : null;
        var block = container.BlockId.HasValue ? await _context.Blocks.FirstOrDefaultAsync(b => b.BlockId == container.BlockId) : null;
        var bay = container.BayId.HasValue ? await _context.Bays.FirstOrDefaultAsync(b => b.BayId == container.BayId) : null;
        var row = container.RowId.HasValue ? await _context.Rows.FirstOrDefaultAsync(r => r.RowId == container.RowId) : null;

        return new ContainerLocationHierarchyDto
        {
            ContainerId = container.ContainerId,
            ContainerNumber = container.ContainerNumber,
            PortDesc = port?.PortDesc ?? "Unknown Port",
            YardNumber = yard?.YardNumber,
            BlockDesc = block?.BlockDesc,
            BayNumber = bay?.BayNumber,
            RowNumber = row?.RowNumber,
            Tier = container.Tier
        };
    }

    public async Task<IEnumerable<Container>> GetContainersByRowIdAsync(int rowId)
    {
        return await _context.Containers
            .Where(c => c.RowId == rowId)
            .OrderBy(c => c.Tier)
            .ToListAsync();
    }

    public async Task<IEnumerable<Container>> GetContainersByLocationAsync(int? yardId, int? blockId, int? bayId, int? rowId)
    {
        var query = _context.Containers.AsQueryable();

        if (yardId.HasValue)   query = query.Where(c => c.YardId == yardId);
        if (blockId.HasValue)  query = query.Where(c => c.BlockId == blockId);
        if (bayId.HasValue)    query = query.Where(c => c.BayId == bayId);
        if (rowId.HasValue)    query = query.Where(c => c.RowId == rowId);

        return await query.OrderBy(c => c.RowId).ThenBy(c => c.Tier).ToListAsync();
    }

    public async Task<Container?> UpdateContainerLocationAsync(int containerId, UpdateContainerLocationDto updateDto)
    {
        var container = await _context.Containers.FindAsync(containerId);
        if (container == null) return null;

        // If moving to holding area (all nulls)
        if (updateDto.YardId == null && updateDto.BlockId == null && 
            updateDto.BayId == null && updateDto.RowId == null && updateDto.Tier == null)
        {
            container.YardId = null;
            container.BlockId = null;
            container.BayId = null;
            container.RowId = null;
            container.Tier = null;
        }
        else
        {
            // Validate all location fields are provided for slot assignment
            if (updateDto.YardId == null || updateDto.BlockId == null || 
                updateDto.BayId == null || updateDto.RowId == null || updateDto.Tier == null)
            {
                throw new ArgumentException("All location fields must be provided for slot assignment");
            }

            // Validate location hierarchy exists - check each level separately
            var yard = await _context.Yards.FirstOrDefaultAsync(y => y.YardId == updateDto.YardId);
            if (yard == null)
            {
                throw new ArgumentException("Invalid YardId");
            }

            var block = await _context.Blocks.FirstOrDefaultAsync(b => b.BlockId == updateDto.BlockId && b.YardId == updateDto.YardId);
            if (block == null)
            {
                throw new ArgumentException("Invalid BlockId for the specified Yard");
            }

            var bay = await _context.Bays.FirstOrDefaultAsync(b => b.BayId == updateDto.BayId && b.BlockId == updateDto.BlockId);
            if (bay == null)
            {
                throw new ArgumentException("Invalid BayId for the specified Block");
            }

            var row = await _context.Rows.FirstOrDefaultAsync(r => r.RowId == updateDto.RowId && r.BayId == updateDto.BayId);
            if (row == null)
            {
                throw new ArgumentException("Invalid RowId for the specified Bay");
            }

            // Validate tier range using row's MaxStack
            var maxStack = row.MaxStack > 0 ? row.MaxStack : 5;
            if (updateDto.Tier < 1 || updateDto.Tier > maxStack)
            {
                throw new ArgumentException($"Tier must be between 1 and {maxStack}");
            }

            // Validate FILO stacking rules - check containers in same row
            var containersInRow = await _context.Containers
                .Where(c => c.RowId == updateDto.RowId && c.ContainerId != containerId)
                .OrderBy(c => c.Tier)
                .ToListAsync();

            // Check if target tier is already occupied
            if (containersInRow.Any(c => c.Tier == updateDto.Tier))
            {
                throw new InvalidOperationException("Target tier position is already occupied");
            }

            // Check FILO rule - all lower tiers must be occupied before stacking higher
            for (int tier = 1; tier < updateDto.Tier; tier++)
            {
                if (!containersInRow.Any(c => c.Tier == tier))
                {
                    throw new ArgumentException($"FILO violation: Tier {tier} must be occupied before placing container in tier {updateDto.Tier}");
                }
            }

            container.YardId = updateDto.YardId;
            container.BlockId = updateDto.BlockId;
            container.BayId = updateDto.BayId;
            container.RowId = updateDto.RowId;
            container.Tier = updateDto.Tier;
        }

        await _context.SaveChangesAsync();
        return container;
    }

    public async Task<Container?> MoveOutContainerAsync(int containerId, MoveOutContainerDto dto)
    {
        var container = await _context.Containers.FindAsync(containerId);
        if (container == null) return null;

        var truckExists = await _context.Trucks.AnyAsync(t => t.TruckId == dto.TruckId);
        if (!truckExists) throw new ArgumentException("Invalid TruckId");

        // Clear slot location, set moved-out status
        container.YardId = null;
        container.BlockId = null;
        container.BayId = null;
        container.RowId = null;
        container.Tier = null;
        container.LocationStatusId = 2; // Moved Out
        container.TruckId = dto.TruckId;
        container.BoundTo = dto.BoundTo;

        await _context.SaveChangesAsync();
        return container;
    }

    public async Task<IEnumerable<Container>> GetMovedOutContainersAsync(int portId)
    {
        return await _context.Containers
            .Where(c => c.CurrentPortId == portId && c.LocationStatusId == 2)
            .ToListAsync();
    }
}