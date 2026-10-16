using System.Text.RegularExpressions;

namespace SyncServer.Domain;

/// <summary>Which space a request is about: 32 lowercase hex characters derived from the user's sync key.</summary>
public readonly partial record struct SpaceId
{
    private SpaceId(string value) => Value = value;

    public string Value { get; }

    public static bool TryParse(string? text, out SpaceId id)
    {
        id = default;
        if (text is null || !Pattern().IsMatch(text))
        {
            return false;
        }
        id = new SpaceId(text);
        return true;
    }

    public override string ToString() => Value;

    [GeneratedRegex("^[0-9a-f]{32}$")]
    private static partial Regex Pattern();
}

/// <summary>The kinds of record a space holds.</summary>
public enum RecordKind
{
    /// <summary><c>h/…</c>: a clipboard history item. May be dropped for space or age.</summary>
    History,

    /// <summary><c>f/…</c>: a favourite. Kept until deleted.</summary>
    Favourite,
}

public static class RecordKinds
{
    public static bool TryParse(string? text, out RecordKind kind)
    {
        switch (text)
        {
            case "h":
                kind = RecordKind.History;
                return true;
            case "f":
                kind = RecordKind.Favourite;
                return true;
            default:
                kind = default;
                return false;
        }
    }

    public static string Prefix(this RecordKind kind) => kind == RecordKind.History ? "h/" : "f/";
}

/// <summary>A record's key, <c>kind/id</c>, where the id is base64url.</summary>
public readonly partial record struct RecordKey
{
    private RecordKey(RecordKind kind, string id)
    {
        Kind = kind;
        Value = kind.Prefix() + id;
    }

    public RecordKind Kind { get; }

    public string Value { get; }

    public static bool TryParse(string? kind, string? id, out RecordKey key)
    {
        key = default;
        if (!RecordKinds.TryParse(kind, out var parsedKind) || id is null || !IdPattern().IsMatch(id))
        {
            return false;
        }
        key = new RecordKey(parsedKind, id);
        return true;
    }

    public override string ToString() => Value;

    [GeneratedRegex("^[A-Za-z0-9_-]{1,64}$")]
    private static partial Regex IdPattern();
}
