using System.IO;
using System.Reflection;
using Yippy.UseCases.Abstractions;

namespace Yippy.Platform.Windows.Input;

/// <summary>
/// <c>scripts/Use-CairnForWinV.ps1</c> and <c>scripts/Restore-WindowsWinV.ps1</c>, embedded in this assembly
/// (see the project file) so Cairn.exe carries them wherever it goes.
/// </summary>
public sealed class EmbeddedClipboardShortcutScripts : IClipboardShortcutScripts
{
    private const string ResourcePrefix = "Yippy.Scripts.";

    private static readonly Assembly Assembly = typeof(EmbeddedClipboardShortcutScripts).Assembly;

    public IReadOnlyList<string> FileNames { get; } = Assembly.GetManifestResourceNames()
        .Where(name => name.StartsWith(ResourcePrefix, StringComparison.Ordinal))
        .Select(name => name[ResourcePrefix.Length..])
        .Order(StringComparer.OrdinalIgnoreCase)
        .ToList();

    public IReadOnlyList<string> SaveTo(string folder)
    {
        Directory.CreateDirectory(folder);
        var written = new List<string>();
        foreach (var fileName in FileNames)
        {
            using var resource = Assembly.GetManifestResourceStream(ResourcePrefix + fileName)
                ?? throw new InvalidOperationException($"The script {fileName} is missing from Cairn.");
            var path = Path.Combine(folder, fileName);
            using var file = File.Create(path);
            resource.CopyTo(file);
            written.Add(path);
        }
        return written;
    }
}
