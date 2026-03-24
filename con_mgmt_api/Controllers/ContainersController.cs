using ContainerManagementApi.DTOs;
using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ContainersController : ControllerBase
{
    private readonly IContainerService _containerService;

    public ContainersController(IContainerService containerService)
    {
        _containerService = containerService;
    }

    [HttpPost]
    public async Task<IActionResult> CreateContainer([FromBody] CreateContainerDto createDto)
    {
        try
        {
            var container = await _containerService.CreateContainerAsync(createDto);
            return CreatedAtAction(nameof(GetContainerById), new { id = container.ContainerId }, container);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetContainersByPortId([FromQuery] int portId)
    {
        var containers = await _containerService.GetContainersByPortIdAsync(portId);
        return Ok(containers);
    }

    [HttpGet("row/{rowId}")]
    public async Task<IActionResult> GetContainersByRowId(int rowId)
    {
        var containers = await _containerService.GetContainersByRowIdAsync(rowId);
        return Ok(containers);
    }

    [HttpGet("location")]
    public async Task<IActionResult> GetContainersByLocation(
        [FromQuery] int? yardId,
        [FromQuery] int? blockId,
        [FromQuery] int? bayId,
        [FromQuery] int? rowId)
    {
        var containers = await _containerService.GetContainersByLocationAsync(yardId, blockId, bayId, rowId);
        return Ok(containers);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetContainerById(int id)
    {
        var container = await _containerService.GetContainerByIdAsync(id);
        if (container == null)
        {
            return NotFound($"Container with ID {id} not found");
        }
        return Ok(container);
    }

    [HttpGet("search")]
    public async Task<IActionResult> SearchContainerByNumber([FromQuery] string containerNumber)
    {
        var container = await _containerService.GetContainerByNumberAsync(containerNumber);
        if (container == null)
        {
            return NotFound($"Container with number {containerNumber} not found");
        }
        return Ok(container);
    }

    [HttpGet("{id}/location-hierarchy")]
    public async Task<IActionResult> GetContainerLocationHierarchy(int id)
    {
        var hierarchy = await _containerService.GetContainerLocationHierarchyAsync(id);
        if (hierarchy == null)
        {
            return NotFound($"Container with ID {id} not found");
        }
        return Ok(hierarchy);
    }

    [HttpPut("{id}/moveout")]
    public async Task<IActionResult> MoveOutContainer(int id, [FromBody] MoveOutContainerDto dto)
    {
        try
        {
            var container = await _containerService.MoveOutContainerAsync(id, dto);
            if (container == null) return NotFound($"Container with ID {id} not found");
            return Ok(container);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpGet("movedout")]
    public async Task<IActionResult> GetMovedOutContainers([FromQuery] int portId)
    {
        var containers = await _containerService.GetMovedOutContainersAsync(portId);
        return Ok(containers);
    }

    [HttpPut("{id}/location")]
    public async Task<IActionResult> UpdateContainerLocation(int id, [FromBody] UpdateContainerLocationDto updateDto)
    {
        try
        {
            var container = await _containerService.UpdateContainerLocationAsync(id, updateDto);
            if (container == null)
            {
                return NotFound($"Container with ID {id} not found");
            }
            return Ok(container);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(ex.Message);
        }
    }
}