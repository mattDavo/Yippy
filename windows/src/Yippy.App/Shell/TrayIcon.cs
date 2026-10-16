using System.Windows.Forms;
using Yippy.Domain.Settings;
using Yippy.UseCases.Abstractions;
using Yippy.UseCases.History;
using Yippy.UseCases.Settings;

namespace Yippy.App.Shell;

/// <summary>
/// The notification-area icon, Yippy's counterpart of the macOS menu-bar item: click it to open the panel, right-click for the menu.
/// </summary>
public sealed class TrayIcon : IDisposable
{
    private readonly PanelController panel;
    private readonly WindowManager windows;
    private readonly SettingsService settings;
    private readonly IStartupRegistration startup;
    private readonly HistoryEditingService editing;
    private readonly NotifyIcon icon;

    public TrayIcon(
        PanelController panel,
        WindowManager windows,
        SettingsService settings,
        IStartupRegistration startup,
        HistoryEditingService editing,
        Action quit)
    {
        this.panel = panel;
        this.windows = windows;
        this.settings = settings;
        this.startup = startup;
        this.editing = editing;

        var menu = new ContextMenuStrip();
        menu.Opening += (_, _) => Fill(menu, quit);
        Fill(menu, quit);
        icon = new NotifyIcon
        {
            Icon = LoadIcon(),
            Text = "Cairn",
            ContextMenuStrip = menu,
            Visible = true,
        };
        icon.MouseClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
            {
                panel.Toggle();
            }
        };
    }

    /// <summary>Shows a notification from the icon.</summary>
    public void Notify(string title, string text, bool isWarning = false)
    {
        icon.ShowBalloonTip(5000, title, text, isWarning ? ToolTipIcon.Warning : ToolTipIcon.Info);
    }

    public void Dispose()
    {
        icon.Visible = false;
        icon.ContextMenuStrip?.Dispose();
        icon.Dispose();
    }

    /// <summary>The same items as the macOS status menu, made again each time so ticks and the shortcut are current.</summary>
    private void Fill(ContextMenuStrip menu, Action quit)
    {
        menu.Items.Clear();
        menu.Items.Add(new ToolStripMenuItem("Show Clipboard History", null, (_, _) => panel.Show())
        {
            ShortcutKeyDisplayString = settings.Current.ToggleHotKey.ToString(),
            Font = new System.Drawing.Font(menu.Font, System.Drawing.FontStyle.Bold),
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("Settings…", null, (_, _) => windows.ShowSettings()));
        menu.Items.Add(new ToolStripMenuItem("Launch at Sign-in", null, (_, _) => startup.SetEnabled(!startup.IsEnabled))
        {
            Checked = startup.IsEnabled,
        });
        menu.Items.Add(PositionMenu());
        menu.Items.Add(new ToolStripMenuItem("Clear History…", null, (_, _) => ClearHistory())
        {
            Enabled = editing.ClipboardHistory.Items.Count > 0,
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("Cairn Help", null, (_, _) => windows.ShowHelp()));
        menu.Items.Add(new ToolStripMenuItem("About Cairn", null, (_, _) => windows.ShowSettings(SettingsPage.About)));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("Quit Cairn", null, (_, _) => quit()));
    }

    private ToolStripMenuItem PositionMenu()
    {
        var item = new ToolStripMenuItem("Position");
        foreach (var position in PanelPositions.All)
        {
            item.DropDownItems.Add(new ToolStripMenuItem(position.Title(), null,
                (_, _) => settings.Update(s => s with { PanelPosition = position }))
            {
                Checked = settings.Current.PanelPosition == position,
            });
        }
        return item;
    }

    private void ClearHistory()
    {
        if (windows.Confirm("Clear History", "Delete every item in the clipboard history? Favourites are kept. This can't be undone."))
        {
            editing.Clear(editing.ClipboardHistory);
        }
    }

    private static System.Drawing.Icon LoadIcon()
    {
        var resource = System.Windows.Application.GetResourceStream(new Uri("pack://application:,,,/Cairn;component/Assets/AppIcon.ico"));
        using var stream = resource!.Stream;
        // The small size, so the notification area doesn't scale the 256 px image down badly
        return new System.Drawing.Icon(stream, System.Windows.Forms.SystemInformation.SmallIconSize);
    }
}
