using Microsoft.EntityFrameworkCore;
using ContainerManagementApi.Models;

namespace ContainerManagementApi.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Port> Ports { get; set; } = null!;
    public DbSet<Yard> Yards { get; set; } = null!;
    public DbSet<Block> Blocks { get; set; } = null!;
    public DbSet<Bay> Bays { get; set; } = null!;
    public DbSet<Row> Rows { get; set; } = null!;
    public DbSet<Container> Containers { get; set; } = null!;
    public DbSet<Status> Statuses { get; set; } = null!;
    public DbSet<Truck> Trucks { get; set; } = null!;
    public DbSet<LocationStatus> LocationStatuses { get; set; } = null!;
    public DbSet<Size> Sizes { get; set; } = null!;
    public DbSet<Orientation> Orientations { get; set; } = null!;
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<UserType> UserTypes { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Container>(entity =>
        {
            entity.HasKey(e => e.ContainerId);
            entity.Property(e => e.CurrentPortId).HasColumnName("CurrentPortId");
            entity.Ignore("Port");
            entity.Ignore("Yard");
            entity.Ignore("Block");
            entity.Ignore("Bay");
            entity.Ignore("Row");
            entity.Ignore("Slot");
        });
    }
}
