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
        if (yard == null) return NotFound($"Yard with ID {id} not found");
        return Ok(yard);
    }

    [HttpPost("{id}/image")]
    public async Task<IActionResult> UploadYardImage(int id, IFormFile file)
    {
        if (file == null || file.Length == 0) return BadRequest("No file provided.");
        var yard = await _yardService.GetYardByIdAsync(id);
        if (yard == null) return NotFound();

        // Use the app's base directory so the path is always reliable
        var folder = Path.Combine(AppContext.BaseDirectory, "wwwroot", "yard-images");
        Directory.CreateDirectory(folder);
        var ext = Path.GetExtension(file.FileName);
        var fileName = $"yard{id}{ext}";
        var filePath = Path.Combine(folder, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
            await file.CopyToAsync(stream);

        var imagePath = $"/yard-images/{fileName}";
        await _yardService.UpdateYardImageAsync(id, imagePath);
        return Ok(new { imagePath });
    }
}