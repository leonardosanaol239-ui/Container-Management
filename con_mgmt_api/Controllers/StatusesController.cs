using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StatusesController : ControllerBase
{
    private readonly IStatusService _statusService;

    public StatusesController(IStatusService statusService)
    {
        _statusService = statusService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAllStatuses()
    {
        var statuses = await _statusService.GetAllStatusesAsync();
        return Ok(statuses);
    }
}