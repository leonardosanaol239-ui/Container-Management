using ContainerManagementApi.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TrucksController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    public TrucksController(ApplicationDbContext context) => _context = context;

    [HttpGet]
    public async Task<IActionResult> GetTrucks()
    {
        var trucks = await _context.Trucks.ToListAsync();
        return Ok(trucks);
    }
}
