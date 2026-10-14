using Yippy.UseCases.History;

namespace Yippy.UseCases.Settings;

/// <summary>Applies the history length setting to the clipboard history, now and whenever it changes.</summary>
public sealed class HistorySettingsSync
{
    public HistorySettingsSync(SettingsService settings, ItemHistory clipboardHistory)
    {
        clipboardHistory.SetMaxItems(settings.Current.MaxHistory);
        settings.Changed += (_, e) =>
        {
            if (e.Old.MaxHistory != e.Current.MaxHistory)
            {
                clipboardHistory.SetMaxItems(e.Current.MaxHistory);
            }
        };
    }
}
