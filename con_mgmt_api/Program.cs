using Microsoft.EntityFrameworkCore;
using ContainerManagementApi.Data;
using ContainerManagementApi.Services;
using ContainerManagementApi.Middleware;
using System.Text.Json;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:5000");

// Add services to the container
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.WriteIndented = true;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo 
    { 
        Title = "Container Management API", 
        Version = "v1",
        Description = "API for managing shipping containers across multiple ports"
    });
});

// Register application services
builder.Services.AddScoped<IPortService, PortService>();
builder.Services.AddScoped<IYardService, YardService>();
builder.Services.AddScoped<IBlockService, BlockService>();
builder.Services.AddScoped<IBayService, BayService>();
builder.Services.AddScoped<IRowService, RowService>();
builder.Services.AddScoped<IContainerService, ContainerService>();
builder.Services.AddScoped<IStatusService, StatusService>();
builder.Services.AddScoped<ILayoutService, LayoutService>();

// Configure Database Connection - Flexible Local/Remote switching
var useLocalDatabase = builder.Configuration.GetValue<bool>("DatabaseSettings:UseLocalDatabase");
var connectionName = builder.Configuration.GetValue<string>("DatabaseSettings:ConnectionName") ?? "Local";
var connectionString = builder.Configuration.GetConnectionString(connectionName);

Console.WriteLine($"Using {(useLocalDatabase ? "LOCAL" : "REMOTE")} database: {connectionName}");
Console.WriteLine($"Connection: {connectionString?.Substring(0, Math.Min(50, connectionString.Length))}...");
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString));

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Test database connectivity on startup
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    try
    {
        await dbContext.Database.CanConnectAsync();
        Console.WriteLine("✓ Database connection successful!");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"✗ Database connection failed: {ex.Message}");
        throw;
    }
}

// Configure the HTTP request pipeline
// Enable Swagger in all environments for testing
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Container Management API v1");
    c.RoutePrefix = "swagger";
});

app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseCors();
var wwwrootPath = Path.Combine(AppContext.BaseDirectory, "wwwroot");
Directory.CreateDirectory(wwwrootPath);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(wwwrootPath),
    RequestPath = ""
});
app.UseAuthorization();
app.MapControllers();

app.Run();
