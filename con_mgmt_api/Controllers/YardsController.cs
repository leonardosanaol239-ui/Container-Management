using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class YardsController : ControllerBase
{
    private readonly IYardService _yardService;

    public YardsController(IYardService yardService)
    {
        _yardService = yardService;
    }

    [HttpGet]
    public async Task<IActionResult> GetYardsByPortId([FromQuery] int portId)
    {
        var yards = await _yardService.GetYardsByPortIdAsync(portId);
        return Ok(yards);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetYardById(int id)
    {
        var yard = await _yardService.GetYardByIdAsync(id);
        if (yard == null)
        {
            return NotFound($"Yard with ID {id} not found");
        }
        return Ok(yard);
    }
}