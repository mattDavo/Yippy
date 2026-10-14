using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Json.Serialization.Metadata;

namespace Yippy.Infrastructure.Storage;

/// <summary>How Yippy's files are written as JSON.</summary>
public static class JsonDefaults
{
    /// <summary>
    /// Readable, enums as names, and only the state of the domain types: properties that can't be set (computed ones such as
    /// <c>HotKeyGesture.IsValid</c>) are left out, so the domain types need no serialization attributes.
    /// </summary>
    public static JsonSerializerOptions Options { get; } = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
        TypeInfoResolver = new DefaultJsonTypeInfoResolver
        {
            Modifiers = { RemoveComputedProperties },
        },
    };

    private static void RemoveComputedProperties(JsonTypeInfo typeInfo)
    {
        if (typeInfo.Kind != JsonTypeInfoKind.Object)
        {
            return;
        }
        for (var i = typeInfo.Properties.Count - 1; i >= 0; i--)
        {
            if (typeInfo.Properties[i].Set is null)
            {
                typeInfo.Properties.RemoveAt(i);
            }
        }
    }

    /// <summary>Writes the file in one go, so a crash mid-write leaves the old file instead of half a new one.</summary>
    public static void WriteAtomically(string path, object value, Type type)
    {
        var temporary = path + ".tmp";
        using (var stream = File.Create(temporary))
        {
            JsonSerializer.Serialize(stream, value, type, Options);
        }
        File.Move(temporary, path, overwrite: true);
    }
}
