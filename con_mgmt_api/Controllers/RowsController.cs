using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RowsController : ControllerBase
{
    private readonly IRowService _rowService;

    public RowsController(IRowService rowService)
    {
        _rowService = rowService;
    }

    [HttpGet]
    public async Task<IActionResult> GetRowsByBayId([FromQuery] int bayId)
    {
        var rows = await _rowService.GetRowsByBayIdAsync(bayId);
        return Ok(rows);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetRowById(int id)
    {
        var row = await _rowService.GetRowByIdAsync(id);
        if (row == null)
        {
            return NotFound($"Row with ID {id} not found");
        }
        return Ok(row);
    }
}