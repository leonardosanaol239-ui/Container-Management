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

    [HttpPost]
    public async Task<IActionResult> CreateYard([FromBody] CreateYardRequest request)
    {
        var yard = await _yardService.CreateYardAsync(request.PortId, request.YardWidth, request.YardHeight);
        return Ok(yard);
    }

    public record CreateYardRequest(int PortId, double YardWidth, double YardHeight);

    [HttpGet("{id}")]
    public async Task<IActionResult> GetYardById(int id)
    {
        var yard = await _yardService.GetYardByIdAsync(id);
        if (yard == null) return NotFound($"Yard with ID {id} not found");
        return Ok(yard);
    }

    [HttpPost("{id}/image")]
    public async Task<IActionResult> UploadYardImage(int id, IFormFile file,
        [FromServices] Microsoft.AspNetCore.Hosting.IWebHostEnvironment env)
    {
        if (file == null || file.Length == 0) return BadRequest("No file provided.");
        var yard = await _yardService.GetYardByIdAsync(id);
        if (yard == null) return NotFound();

        // Save to WebRootPath (wwwroot) so it's served correctly
        var folder = Path.Combine(env.WebRootPath ?? AppContext.BaseDirectory, "yard-images");
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