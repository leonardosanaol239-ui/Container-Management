using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PortsController : ControllerBase
{
    private readonly IPortService _portService;

    public PortsController(IPortService portService)
    {
        _portService = portService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAllPorts()
    {
        var ports = await _portService.GetAllPortsAsync();
        return Ok(ports);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetPortById(int id)
    {
        var port = await _portService.GetPortByIdAsync(id);
        if (port == null)
        {
            return NotFound($"Port with ID {id} not found");
        }
        return Ok(port);
    }
}