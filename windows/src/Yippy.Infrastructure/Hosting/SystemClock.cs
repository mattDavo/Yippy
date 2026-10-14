using Yippy.UseCases.Abstractions;

namespace Yippy.Infrastructure.Hosting;

public sealed class SystemClock : IClock
{
    public DateTimeOffset Now => DateTimeOffset.Now;
}
