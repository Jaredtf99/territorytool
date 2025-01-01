using Microsoft.EntityFrameworkCore;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence
{
    public partial class TerritoryToolDbContext : DbContext
    {
        public TerritoryToolDbContext()
        {
        }

        public TerritoryToolDbContext(DbContextOptions<TerritoryToolDbContext> options)
            : base(options)
        {
        }

        public virtual DbSet<ActionLog> ActionLog { get; set; }
        public virtual DbSet<AspNetRoleClaims> AspNetRoleClaims { get; set; }
        public virtual DbSet<AspNetRoles> AspNetRoles { get; set; }
        public virtual DbSet<AspNetUserClaims> AspNetUserClaims { get; set; }
        public virtual DbSet<AspNetUserLogins> AspNetUserLogins { get; set; }
        public virtual DbSet<AspNetUserRoles> AspNetUserRoles { get; set; }
        public virtual DbSet<AspNetUsers> AspNetUsers { get; set; }
        public virtual DbSet<AspNetUserTokens> AspNetUserTokens { get; set; }
        public virtual DbSet<Person> Person { get; set; }
        public virtual DbSet<Territory> Territory { get; set; }
        public virtual DbSet<Transaction> Transaction { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ActionLog>(entity =>
            {
                entity.HasIndex(e => e.Id)
                    .IsUnique();

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.DateTimeUtc)
                    .IsRequired()
                    .HasColumnName("DateTimeUTC")
                    .HasColumnType("DATETIME");

                entity.Property(e => e.Successful)
                    .IsRequired()
                    .HasColumnType("BOOLEAN");

                entity.Property(e => e.UserId).IsRequired();

                entity.HasOne(d => d.User)
                    .WithMany(p => p.ActionLog)
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.ClientSetNull);
            });

            modelBuilder.Entity<AspNetRoleClaims>(entity =>
            {
                entity.HasIndex(e => e.RoleId);

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.RoleId).IsRequired();

                entity.HasOne(d => d.Role)
                    .WithMany(p => p.AspNetRoleClaims)
                    .HasForeignKey(d => d.RoleId);
            });

            modelBuilder.Entity<AspNetRoles>(entity =>
            {
                entity.HasIndex(e => e.NormalizedName)
                    .HasName("RoleNameIndex")
                    .IsUnique();

                entity.Property(e => e.Id).ValueGeneratedOnAdd();
            });

            modelBuilder.Entity<AspNetUserClaims>(entity =>
            {
                entity.HasIndex(e => e.UserId);

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.UserId).IsRequired();

                entity.HasOne(d => d.User)
                    .WithMany(p => p.AspNetUserClaims)
                    .HasForeignKey(d => d.UserId);
            });

            modelBuilder.Entity<AspNetUserLogins>(entity =>
            {
                entity.HasKey(e => new { e.LoginProvider, e.ProviderKey });

                entity.HasIndex(e => e.UserId);

                entity.Property(e => e.UserId).IsRequired();

                entity.HasOne(d => d.User)
                    .WithMany(p => p.AspNetUserLogins)
                    .HasForeignKey(d => d.UserId);
            });

            modelBuilder.Entity<AspNetUserRoles>(entity =>
            {
                entity.HasKey(e => new { e.UserId, e.RoleId });

                entity.HasIndex(e => e.RoleId);

                entity.HasOne(d => d.Role)
                    .WithMany(p => p.AspNetUserRoles)
                    .HasForeignKey(d => d.RoleId);

                entity.HasOne(d => d.User)
                    .WithMany(p => p.AspNetUserRoles)
                    .HasForeignKey(d => d.UserId);
            });

            modelBuilder.Entity<AspNetUsers>(entity =>
            {
                entity.HasIndex(e => e.NormalizedEmail)
                    .HasName("EmailIndex");

                entity.HasIndex(e => e.NormalizedUserName)
                    .HasName("UserNameIndex")
                    .IsUnique();

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.Discriminator).IsRequired();
            });

            modelBuilder.Entity<AspNetUserTokens>(entity =>
            {
                entity.HasKey(e => new { e.UserId, e.LoginProvider, e.Name });

                entity.HasOne(d => d.User)
                    .WithMany(p => p.AspNetUserTokens)
                    .HasForeignKey(d => d.UserId);
            });

            modelBuilder.Entity<Person>(entity =>
            {
                entity.HasIndex(e => e.Id)
                    .IsUnique();

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.Name).IsRequired();
            });

            modelBuilder.Entity<Territory>(entity =>
            {
                entity.HasIndex(e => e.Code)
                    .IsUnique();

                entity.HasIndex(e => e.Id)
                    .IsUnique();

                entity.HasIndex(e => e.MapUrl)
                    .IsUnique();

                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.Code).IsRequired();

                entity.Property(e => e.PersonId).HasColumnType("INT");

                entity.Property(e => e.MapUrl).IsRequired();

                entity.Property(e => e.Name).IsRequired();

                entity.HasOne(d => d.Person)
                    .WithMany(p => p.TerritoriesInUse)
                    .HasForeignKey(d => d.PersonId)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasMany(t => t.Transactions)
                    .WithOne(tr => tr.Territory)
                    .HasForeignKey(tr => tr.TerritoryId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Transaction>(entity =>
            {
                entity.Property(e => e.Id).ValueGeneratedOnAdd();

                entity.Property(e => e.GivenBy).IsRequired();

                entity.Property(e => e.GivenDateUtc)
                    .IsRequired()
                    .HasColumnType("DATETIME");

                entity.Property(e => e.IsAutomaticGivenDate)
                    .IsRequired()
                    .HasColumnType("BOOLEAN");

                entity.Property(e => e.IsAutomaticPickedDate).HasColumnType("BOOLEAN");

                entity.Property(e => e.PersonId).HasColumnType("INT");

                entity.Property(e => e.PickedDateUtc)
                    .HasColumnName("PickedDateUTC")
                    .HasColumnType("DATETIME");

                entity.Property(e => e.TerritoryId).HasColumnType("INT");

                entity.HasOne(d => d.GivenByNavigation)
                    .WithMany(p => p.TransactionGivenByNavigation)
                    .HasForeignKey(d => d.GivenBy)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.Person)
                    .WithMany(p => p.Transactions)
                    .HasForeignKey(d => d.PersonId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(d => d.PickedByNavigation)
                    .WithMany(p => p.TransactionPickedByNavigation)
                    .HasForeignKey(d => d.PickedBy)
                    .OnDelete(DeleteBehavior.SetNull);

                entity.HasOne(d => d.Territory)
                    .WithMany(p => p.Transactions)
                    .HasForeignKey(d => d.TerritoryId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}
