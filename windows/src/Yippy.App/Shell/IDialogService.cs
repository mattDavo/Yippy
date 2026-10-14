namespace Yippy.App.Shell;

/// <summary>Dialogs the view models ask for, so they don't create windows themselves.</summary>
public interface IDialogService
{
    /// <summary>Asks for a line of text (or several, when <paramref name="multiline"/>).</summary>
    /// <returns>The text, or null if cancelled.</returns>
    string? Prompt(string title, string message, string initialText, bool multiline = false);

    /// <returns>Whether the user confirmed.</returns>
    bool Confirm(string title, string message);

    /// <returns>The path of the executable the user picked, or null if cancelled.</returns>
    string? PickExecutable();

    /// <returns>The folder the user picked, or null if cancelled.</returns>
    string? PickFolder(string title);
}
