using ContainerManagementApi.DTOs;
using ContainerManagementApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ContainerManagementApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService)
    {
        _userService = userService;
    }

    // GET api/Users
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var users = await _userService.GetAllUsersAsync();
        return Ok(users);
    }

    // GET api/Users/5
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var user = await _userService.GetUserByIdAsync(id);
        if (user == null) return NotFound($"User with ID {id} not found.");
        return Ok(user);
    }

    // POST api/Users
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] SaveUserDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        try
        {
            var created = await _userService.CreateUserAsync(dto);
            return CreatedAtAction(nameof(GetById), new { id = created.UserId }, created);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    // PUT api/Users/5
    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] SaveUserDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        try
        {
            var updated = await _userService.UpdateUserAsync(id, dto);
            if (updated == null) return NotFound($"User with ID {id} not found.");
            return Ok(updated);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
