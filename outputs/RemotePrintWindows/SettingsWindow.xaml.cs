using RemotePrintWindows.Services;
using System.Windows;

namespace RemotePrintWindows;

public partial class SettingsWindow : Window
{
    public SettingsWindow()
    {
        InitializeComponent();
        var settings = ConnectionSettingsStore.Load();
        ApiBox.Text = settings.ApiBaseUrl;
        DeviceBox.Text = settings.DeviceName;
        CodeBox.Text = settings.ActivationCode;
        BehaviorBox.SelectedIndex = settings.PrintBehavior == PrintBehavior.Silent ? 1 : 0;
    }

    private void Save(object sender, RoutedEventArgs e)
    {
        if (!Uri.TryCreate(ApiBox.Text.Trim(), UriKind.Absolute, out var endpoint) || endpoint.Scheme is not ("https" or "http"))
        {
            MessageBox.Show("请输入以 http:// 或 https:// 开头的 API 地址。", "接入配置");
            return;
        }
        var previous = ConnectionSettingsStore.Load();
        var apiBaseUrl = endpoint.ToString().TrimEnd('/');
        var activationCode = CodeBox.Text.Trim();
        var credentialsChanged = previous.ApiBaseUrl != apiBaseUrl || previous.ActivationCode != activationCode;
        ConnectionSettingsStore.Save(new ConnectionSettings {
            ApiBaseUrl = apiBaseUrl,
            DeviceName = string.IsNullOrWhiteSpace(DeviceBox.Text) ? "本机远程打印终端" : DeviceBox.Text.Trim(),
            ActivationCode = activationCode,
            DeviceId = credentialsChanged ? "" : previous.DeviceId,
            AccessToken = credentialsChanged ? "" : previous.AccessToken,
            PollIntervalSeconds = previous.PollIntervalSeconds,
            PrintBehavior = BehaviorBox.SelectedIndex == 1 ? PrintBehavior.Silent : PrintBehavior.Confirm
        });
        DialogResult = true;
    }

    private void Cancel(object sender, RoutedEventArgs e) => DialogResult = false;
}
