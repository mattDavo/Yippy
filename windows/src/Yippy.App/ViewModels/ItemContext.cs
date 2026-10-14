using Yippy.App.Presentation;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.App.ViewModels;

/// <summary>What every <see cref="ItemViewModel"/> needs, passed as one object instead of five.</summary>
public sealed record ItemContext(
    SettingsService Settings,
    HistoryEditingService Editing,
    IAppInfoProvider AppInfo,
    AppIcons Icons,
    IClock Clock);
