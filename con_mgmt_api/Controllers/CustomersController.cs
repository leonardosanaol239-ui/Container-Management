using ContainerManagementApi.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly ApplicationDbContext _ctx;
    public CustomersController(ApplicationDbContext ctx) => _ctx = ctx;

    [HttpGet]
    public async Task<IActionResult> GetAll() =>
        Ok(await _ctx.Customers.ToListAsync());
}
