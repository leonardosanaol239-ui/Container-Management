using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BaysController : ControllerBase
{
    private readonly IBayService _bayService;

    public BaysController(IBayService bayService)
    {
        _bayService = bayService;
    }

    [HttpGet]
    public async Task<IActionResult> GetBaysByBlockId([FromQuery] int blockId)
    {
        var bays = await _bayService.GetBaysByBlockIdAsync(blockId);
        return Ok(bays);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetBayById(int id)
    {
        var bay = await _bayService.GetBayByIdAsync(id);
        if (bay == null)
        {
            return NotFound($"Bay with ID {id} not found");
        }
        return Ok(bay);
    }
}