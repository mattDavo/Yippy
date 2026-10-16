namespace SyncServer.Application;

/// <summary>A request the server refuses. The API turns it into an error response.</summary>
public sealed class SyncException : Exception
{
    public SyncException(SyncError error, string message)
        : base(message)
    {
        Error = error;
    }

    public SyncError Error { get; }
}

public enum SyncError
{
    /// <summary>The auth token doesn't match the space's.</summary>
    Unauthorized,

    TooLarge,
}
