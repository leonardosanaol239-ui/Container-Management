using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BlocksController : ControllerBase
{
    private readonly IBlockService _blockService;

    public BlocksController(IBlockService blockService)
    {
        _blockService = blockService;
    }

    [HttpGet]
    public async Task<IActionResult> GetBlocksByYardId([FromQuery] int yardId)
    {
        var blocks = await _blockService.GetBlocksByYardIdAsync(yardId);
        return Ok(blocks);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetBlockById(int id)
    {
        var block = await _blockService.GetBlockByIdAsync(id);
        if (block == null)
        {
            return NotFound($"Block with ID {id} not found");
        }
        return Ok(block);
    }
}