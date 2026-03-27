using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LayoutController : ControllerBase
{
    private readonly ILayoutService _layout;

    public LayoutController(ILayoutService layout) => _layout = layout;

    [HttpGet("sizes")]
    public async Task<IActionResult> GetSizes() =>
        Ok(await _layout.GetSizesAsync());

    [HttpGet("orientations")]
    public async Task<IActionResult> GetOrientations() =>
        Ok(await _layout.GetOrientationsAsync());

    [HttpPost("blocks")]
    public async Task<IActionResult> CreateBlock([FromBody] CreateBlockRequest req)
    {
        var block = await _layout.CreateBlockAsync(req);
        return Ok(block);
    }

    [HttpPut("blocks/{id}/position")]
    public async Task<IActionResult> UpdateBlockPosition(int id, [FromBody] UpdateBlockPositionRequest req)
    {
        var block = await _layout.UpdateBlockPositionAsync(id, req.PosX, req.PosY);
        if (block == null) return NotFound();
        return Ok(block);
    }

    [HttpDelete("blocks/{id}")]
    public async Task<IActionResult> DeleteBlock(int id)
    {
        var ok = await _layout.DeleteBlockAsync(id);
        if (!ok) return BadRequest("Cannot delete block: it still has containers.");
        return NoContent();
    }

    [HttpGet("blocks/{id}/debug-containers")]
    public async Task<IActionResult> DebugBlockContainers(int id) =>
        Ok(await _layout.GetBlockContainersDebugAsync(id));

    [HttpPost("blocks/{id}/bays")]
    public async Task<IActionResult> AddBay(int id)
    {
        var block = await _layout.AddBayAsync(id);
        if (block == null) return NotFound();
        return Ok(block);
    }

    [HttpDelete("blocks/{id}/bays")]
    public async Task<IActionResult> RemoveBay(int id)
    {
        var ok = await _layout.RemoveBayAsync(id);
        if (!ok) return BadRequest("Cannot remove bay: it has containers or only 1 bay remains.");
        return NoContent();
    }

    [HttpPost("blocks/{id}/rows")]
    public async Task<IActionResult> AddRow(int id)
    {
        var ok = await _layout.AddRowAsync(id);
        if (!ok) return BadRequest("Cannot add row.");
        return Ok();
    }

    [HttpDelete("blocks/{id}/rows")]
    public async Task<IActionResult> RemoveRow(int id)
    {
        var ok = await _layout.RemoveRowAsync(id);
        if (!ok) return BadRequest("Cannot remove row: it has containers or only 1 row remains.");
        return NoContent();
    }

    // Rows are now the slot — update/delete directly by rowId
    [HttpPut("rows/{id}")]
    public async Task<IActionResult> UpdateRow(int id, [FromBody] UpdateSlotRequest req)
    {
        var row = await _layout.UpdateRowAsync(id, req);
        if (row == null) return NotFound();
        return Ok(row);
    }

    [HttpDelete("rows/{id}")]
    public async Task<IActionResult> DeleteRow(int id)
    {
        var ok = await _layout.DeleteRowAsync(id);
        if (!ok) return BadRequest("Cannot delete row: it has containers or was not found.");
        return NoContent();
    }
}
