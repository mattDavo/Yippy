using System.Diagnostics;
using Yippy.UseCases.Abstractions;

namespace Yippy.Infrastructure.Logging;

/// <summary>Appends errors to <c>error.log</c> and warnings to <c>warning.log</c> in the app's data folder.</summary>
public sealed class FileAppLogger : IAppLogger
{
    private readonly object gate = new();
    private readonly string errorLog;
    private readonly string warningLog;

    public FileAppLogger(string directory)
    {
        errorLog = Path.Combine(directory, "error.log");
        warningLog = Path.Combine(directory, "warning.log");
    }

    public void Error(string message, Exception? exception = null)
    {
        Append(errorLog, exception is null ? message : $"{message}{Environment.NewLine}{exception}");
    }

    public void Warning(string message) => Append(warningLog, message);

    private void Append(string path, string message)
    {
        var line = $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}";
        Debug.Write(line);
        lock (gate)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                File.AppendAllText(path, line);
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException)
            {
                // Logging must never take the app down
            }
        }
    }
}
