using Yippy.UseCases.Abstractions;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.UseCases.Recognition;

/// <summary>
/// Reads the text in copied images while "Recognise text in images" is on, so search can find screenshots by what they say.
/// </summary>
/// <remarks>
/// Reads every unread image when the setting is turned on, then each new one, one at a time. The text is saved in the item's
/// metadata ("" when there is none, so it isn't read again). Use from the UI thread.
/// </remarks>
public sealed class TextRecognitionService
{
    /// <summary>Longer text is cut off, to keep the index file small.</summary>
    public const int MaxTextLength = 10_000;

    private readonly ITextRecognizer recognizer;
    private readonly SettingsService settings;
    private readonly IAppLogger logger;
    private readonly IReadOnlyList<ItemHistory> histories;
    private readonly List<(ItemHistory History, Guid Id)> pending = new();
    private CancellationTokenSource stop = new();
    private bool isRunning;

    public TextRecognitionService(ITextRecognizer recognizer, SettingsService settings, IAppLogger logger, params ItemHistory[] histories)
    {
        this.recognizer = recognizer;
        this.settings = settings;
        this.logger = logger;
        this.histories = histories;

        settings.Changed += (_, e) =>
        {
            if (e.Old.RecognizesTextInImages != e.Current.RecognizesTextInImages)
            {
                OnEnabledChanged();
            }
        };
        foreach (var history in histories)
        {
            history.Changed += (_, change) =>
            {
                if (change is HistoryChange.Inserted inserted)
                {
                    Enqueue(history, inserted.Item.Id);
                }
            };
        }
        OnEnabledChanged();
    }

    public bool IsEnabled => settings.Current.RecognizesTextInImages && recognizer.IsAvailable;

    private void OnEnabledChanged()
    {
        if (!IsEnabled)
        {
            pending.Clear();
            stop.Cancel();
            stop = new CancellationTokenSource();
            return;
        }
        foreach (var history in histories)
        {
            foreach (var item in history.Items)
            {
                Enqueue(history, item.Id);
            }
        }
    }

    private void Enqueue(ItemHistory history, Guid id)
    {
        if (!IsEnabled || pending.Any(p => p.Id == id))
        {
            return;
        }
        var index = history.IndexOf(id);
        if (index < 0 || !history.Items[index].IsImage || history.Items[index].Metadata.RecognizedText is not null)
        {
            return;
        }
        pending.Add((history, id));
        _ = ReadPendingAsync();
    }

    private async Task ReadPendingAsync()
    {
        if (isRunning)
        {
            return;
        }
        isRunning = true;
        try
        {
            while (pending.Count > 0)
            {
                var (history, id) = pending[0];
                pending.RemoveAt(0);
                // Skip items deleted or read since they were queued
                var index = history.IndexOf(id);
                if (index < 0 || history.Items[index].Metadata.RecognizedText is not null || history.Items[index].GetImage() is not { } image)
                {
                    continue;
                }
                var token = stop.Token;
                string? text;
                try
                {
                    text = await recognizer.RecognizeAsync(image.Data, token);
                }
                catch (Exception e) when (e is not OperationCanceledException)
                {
                    logger.Warning($"Couldn't read the text in image {id}: {e.Message}");
                    text = null;
                }
                catch (OperationCanceledException)
                {
                    continue;
                }
                if (token.IsCancellationRequested || text is null)
                {
                    continue;
                }
                var trimmed = text.Length > MaxTextLength ? text[..MaxTextLength] : text;
                history.UpdateMetadata(id, m => m with { RecognizedText = trimmed });
            }
        }
        finally
        {
            isRunning = false;
        }
    }
}
