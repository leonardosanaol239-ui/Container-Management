using ContainerManagementApi.Data;
using ContainerManagementApi.Models;
using Microsoft.EntityFrameworkCore;

namespace ContainerManagementApi.Services;

public class PortService : IPortService
{
    private readonly ApplicationDbContext _context;

    public PortService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Port>> GetAllPortsAsync()
    {
        return await _context.Ports.ToListAsync();
    }

    public async Task<Port?> GetPortByIdAsync(int portId)
    {
        return await _context.Ports.FindAsync(portId);
    }
}