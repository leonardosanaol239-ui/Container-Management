using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class LayoutService : ILayoutService
{
    private readonly ApplicationDbContext _ctx;

    public LayoutService(ApplicationDbContext ctx) => _ctx = ctx;

    public async Task<IEnumerable<Size>> GetSizesAsync() =>
        await _ctx.Sizes.ToListAsync();

    public async Task<IEnumerable<Orientation>> GetOrientationsAsync() =>
        await _ctx.Orientations.ToListAsync();

    public async Task<Block> CreateBlockAsync(CreateBlockRequest req)
    {
        var maxNum = await _ctx.Blocks
            .Where(b => b.YardId == req.YardId)
            .MaxAsync(b => (int?)b.BlockNumber) ?? 0;

        var block = new Block
        {
            BlockNumber = maxNum + 1,
            BlockName = req.BlockName,
            BlockDesc = req.BlockName,
            YardId = req.YardId,
            PortId = req.PortId,
            OrientationId = req.OrientationId,
            SizeId = req.SizeId,
            PosX = req.PosX,
            PosY = req.PosY,
        };
        _ctx.Blocks.Add(block);
        await _ctx.SaveChangesAsync();

        var bayLabels = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        for (int b = 0; b < req.NumBays; b++)
        {
            var bay = new Bay { BayNumber = bayLabels[b].ToString(), BlockId = block.BlockId };
            _ctx.Bays.Add(bay);
            await _ctx.SaveChangesAsync();

            for (int r = 0; r < req.NumRows; r++)
            {
                var row = new Row
                {
                    RowNumber = r + 1,
                    BayId = bay.BayId,
                    SizeId = req.SizeId,
                    OrientationId = req.OrientationId,
                    MaxStack = req.MaxStack,
                    IsDeleted = false,
                };
                _ctx.Rows.Add(row);
            }
        }
        await _ctx.SaveChangesAsync();
        return block;
    }

    public async Task<Block?> UpdateBlockPositionAsync(int blockId, double posX, double posY)
    {
        var block = await _ctx.Blocks.FindAsync(blockId);
        if (block == null) return null;
        block.PosX = posX;
        block.PosY = posY;
        await _ctx.SaveChangesAsync();
        return block;
    }

    public async Task<Block?> UpdateBlockRotationAsync(int blockId, double rotation)
    {
        var block = await _ctx.Blocks.FindAsync(blockId);
        if (block == null) return null;
        block.Rotation = rotation;
        await _ctx.SaveChangesAsync();
        return block;
    }

    public async Task<bool> DeleteBlockAsync(int blockId)
    {
        var bayIds = await _ctx.Bays
            .Where(b => b.BlockId == blockId)
            .Select(b => b.BayId)
            .ToListAsync();

        var rowIds = await _ctx.Rows
            .Where(r => bayIds.Contains(r.BayId))
            .Select(r => r.RowId)
            .ToListAsync();

        // Block deletion if any container is actively sitting in a slot in this block
        var hasContainers = rowIds.Any() && await _ctx.Containers
            .AnyAsync(c => c.RowId != null && rowIds.Contains(c.RowId.Value) && c.LocationStatusId != 2);
        if (hasContainers) return false;

        // Step 1: clear all container FK references to this block's rows/bays and save first
        // so FK constraints don't fire when we delete rows/bays below
        var allRowIds = rowIds.ToHashSet();
        var referencedContainers = await _ctx.Containers
            .Where(c => c.BlockId == blockId
                     || (c.BayId != null && bayIds.Contains(c.BayId.Value))
                     || (c.RowId != null && allRowIds.Contains(c.RowId.Value)))
            .ToListAsync();
        foreach (var c in referencedContainers)
        {
            c.BlockId = null;
            c.BayId   = null;
            c.RowId   = null;
            c.Tier    = null;
        }
        await _ctx.SaveChangesAsync(); // commit FK cleanup before deleting rows

        // Step 2: delete rows first, then bays, then block (respect FK order)
        var rows = await _ctx.Rows.Where(r => bayIds.Contains(r.BayId)).ToListAsync();
        _ctx.Rows.RemoveRange(rows);
        await _ctx.SaveChangesAsync();

        var bays = await _ctx.Bays.Where(b => b.BlockId == blockId).ToListAsync();
        _ctx.Bays.RemoveRange(bays);
        await _ctx.SaveChangesAsync();

        var block = await _ctx.Blocks.FindAsync(blockId);
        if (block != null) _ctx.Blocks.Remove(block);
        await _ctx.SaveChangesAsync();
        return true;
    }

    public async Task<object> GetBlockContainersDebugAsync(int blockId)
    {
        var bayIds = await _ctx.Bays
            .Where(b => b.BlockId == blockId)
            .Select(b => b.BayId)
            .ToListAsync();

        var rowIds = await _ctx.Rows
            .Where(r => bayIds.Contains(r.BayId))
            .Select(r => r.RowId)
            .ToListAsync();

        var byBlockId = await _ctx.Containers
            .Where(c => c.BlockId == blockId)
            .Select(c => new { c.ContainerId, c.ContainerNumber, c.BlockId, c.BayId, c.RowId, c.LocationStatusId })
            .ToListAsync();

        var byRowId = await _ctx.Containers
            .Where(c => c.RowId != null && rowIds.Contains(c.RowId.Value))
            .Select(c => new { c.ContainerId, c.ContainerNumber, c.BlockId, c.BayId, c.RowId, c.LocationStatusId })
            .ToListAsync();

        return new { bayIds, rowIds, byBlockId, byRowId };
    }

    public async Task<Block?> AddBayAsync(int blockId)
    {
        var block = await _ctx.Blocks.FindAsync(blockId);
        if (block == null) return null;

        var existingBays = await _ctx.Bays
            .Where(b => b.BlockId == blockId)
            .OrderBy(b => b.BayNumber)
            .ToListAsync();

        var bayLabels = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        var nextLabel = bayLabels[existingBays.Count].ToString();

        int rowCount = 0;
        if (existingBays.Any())
            rowCount = await _ctx.Rows.CountAsync(r => r.BayId == existingBays.First().BayId);

        var bay = new Bay { BayNumber = nextLabel, BlockId = blockId };
        _ctx.Bays.Add(bay);
        await _ctx.SaveChangesAsync();

        for (int r = 0; r < rowCount; r++)
        {
            _ctx.Rows.Add(new Row
            {
                RowNumber = r + 1,
                BayId = bay.BayId,
                SizeId = block.SizeId,
                OrientationId = block.OrientationId,
                MaxStack = 5,
                IsDeleted = false,
            });
        }
        await _ctx.SaveChangesAsync();
        return block;
    }

    public async Task<bool> RemoveBayAsync(int blockId)
    {
        var bays = await _ctx.Bays
            .Where(b => b.BlockId == blockId)
            .OrderBy(b => b.BayId)
            .ToListAsync();

        if (bays.Count <= 1) return false;

        var lastBay = bays.Last();

        // Step 1: clear container references to rows in this bay
        var rowIds = await _ctx.Rows
            .Where(r => r.BayId == lastBay.BayId)
            .Select(r => r.RowId)
            .ToListAsync();

        var containersInBay = await _ctx.Containers
            .Where(c => c.BayId == lastBay.BayId || (c.RowId != null && rowIds.Contains(c.RowId.Value)))
            .ToListAsync();
        foreach (var c in containersInBay)
        {
            c.RowId = null;
            c.BayId = null;
            c.Tier = null;
            c.YardId = null;
            c.BlockId = null;
        }
        await _ctx.SaveChangesAsync();

        // Step 2: delete rows (FK to Bay)
        var rows = await _ctx.Rows.Where(r => r.BayId == lastBay.BayId).ToListAsync();
        _ctx.Rows.RemoveRange(rows);
        await _ctx.SaveChangesAsync();

        // Step 3: delete bay
        _ctx.Bays.Remove(lastBay);
        await _ctx.SaveChangesAsync();

        return true;
    }

    public async Task<Row?> UpdateRowAsync(int rowId, UpdateSlotRequest req)
    {
        var row = await _ctx.Rows.FindAsync(rowId);
        if (row == null) return null;

        if (req.SizeId.HasValue) row.SizeId = req.SizeId;
        if (req.OrientationId.HasValue) row.OrientationId = req.OrientationId;
        if (req.MaxStack.HasValue) row.MaxStack = req.MaxStack.Value;

        await _ctx.SaveChangesAsync();
        return row;
    }

    public async Task<bool> AddRowAsync(int blockId)
    {
        var bays = await _ctx.Bays.Where(b => b.BlockId == blockId).ToListAsync();
        if (!bays.Any()) return false;

        var block = await _ctx.Blocks.FindAsync(blockId);

        // Get current max row number from first bay
        var firstBay = bays.First();
        var maxRowNum = await _ctx.Rows
            .Where(r => r.BayId == firstBay.BayId)
            .MaxAsync(r => (int?)r.RowNumber) ?? 0;

        foreach (var bay in bays)
        {
            _ctx.Rows.Add(new Row
            {
                RowNumber = maxRowNum + 1,
                BayId = bay.BayId,
                SizeId = block?.SizeId,
                OrientationId = block?.OrientationId,
                MaxStack = 5,
                IsDeleted = false,
            });
        }
        await _ctx.SaveChangesAsync();
        return true;
    }

    public async Task<bool> RemoveRowAsync(int blockId)
    {
        var bays = await _ctx.Bays.Where(b => b.BlockId == blockId).ToListAsync();
        if (!bays.Any()) return false;

        var firstBay = bays.First();
        // Only count active (non-deleted) rows
        var activeRows = await _ctx.Rows
            .Where(r => r.BayId == firstBay.BayId && !r.IsDeleted)
            .ToListAsync();
        if (activeRows.Count <= 1) return false;

        // Find the highest row number among active rows
        var maxRowNum = activeRows.Max(r => r.RowNumber);

        foreach (var bay in bays)
        {
            var row = await _ctx.Rows
                .FirstOrDefaultAsync(r => r.BayId == bay.BayId && r.RowNumber == maxRowNum && !r.IsDeleted);
            if (row == null) continue;

            var hasContainers = await _ctx.Containers
                .AnyAsync(c => c.RowId == row.RowId && c.LocationStatusId != 2);
            if (hasContainers) return false;

            _ctx.Rows.Remove(row);
        }
        await _ctx.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeleteRowAsync(int rowId)
    {
        var row = await _ctx.Rows.FindAsync(rowId);
        if (row == null) return false;

        var hasContainers = await _ctx.Containers
            .AnyAsync(c => c.RowId == rowId && c.LocationStatusId != 2);
        if (hasContainers) return false;

        // Mark as deleted (leaves empty space in block)
        row.IsDeleted = true;
        await _ctx.SaveChangesAsync();
        return true;
    }
}
