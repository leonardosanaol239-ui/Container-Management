using ContainerManagementApi.DTOs;

namespace ContainerManagementApi.Services;

public interface IUserService
{
    Task<IEnumerable<UserDto>> GetAllUsersAsync();
    Task<UserDto?> GetUserByIdAsync(int userId);
    Task<UserDto> CreateUserAsync(SaveUserDto dto);
    Task<UserDto?> UpdateUserAsync(int userId, SaveUserDto dto);
}
