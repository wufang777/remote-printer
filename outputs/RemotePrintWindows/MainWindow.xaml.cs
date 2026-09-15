using Microsoft.Win32;
using RemotePrintWindows.Models;
using RemotePrintWindows.Services;
using System.Collections.ObjectModel;
using System.Printing;
using System.Windows;

namespace RemotePrintWindows;
public partial class MainWindow : Window
{
    private string? selectedFile;
    private readonly ObservableCollection<PrintTask> tasks = [];
    private readonly PrinterService printerService = new();
    private readonly RemoteRelayClient remoteClient = new();
    private readonly CancellationTokenSource pollingCancellation = new();
    public MainWindow() { InitializeComponent(); LoadPrinters(); TaskList.ItemsSource = tasks; ApplyPrintBehavior(); Loaded += OnLoaded; Closed += (_, _) => pollingCancellation.Cancel(); }
    private async void OnLoaded(object sender, RoutedEventArgs e) { await ConnectAndPollAsync(pollingCancellation.Token); }
    private void LoadPrinters() { try { foreach (var printer in printerService.GetPrinterNames()) PrinterBox.Items.Add(printer); if (PrinterBox.Items.Count > 0) PrinterBox.SelectedIndex = 0; DeviceText.Text = PrinterBox.SelectedItem?.ToString() ?? "未发现打印机"; } catch (Exception ex) { DeviceText.Text = "读取打印机失败"; MessageBox.Show(ex.Message, "远程打印控制台"); } }
    private void ChooseFile(object sender, RoutedEventArgs e) { var dialog = new OpenFileDialog { Filter = "支持的打印文件|*.pdf;*.jpg;*.jpeg;*.png;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.csv;*.wps;*.et;*.dps" }; if (dialog.ShowDialog() == true) { selectedFile = dialog.FileName; FileNameText.Text = System.IO.Path.GetFileName(selectedFile); } }
    private void ClearFile(object sender, RoutedEventArgs e) { selectedFile = null; FileNameText.Text = "尚未选择 PDF 或图片文件"; }
    private void PreviewFile(object sender, RoutedEventArgs e) { if (selectedFile is null) { MessageBox.Show("请先选择本地文件。", "文件预览"); return; } new PreviewWindow(selectedFile) { Owner = this }.ShowDialog(); }
    private void CreateTask(object sender, RoutedEventArgs e)
    {
        if (selectedFile is null || PrinterBox.SelectedItem is null) { MessageBox.Show("请选择本地文件和目标打印机。", "远程打印控制台"); return; }
        var task = new PrintTask { FileName = Path.GetFileName(selectedFile), FilePath = selectedFile, PrinterName = PrinterBox.SelectedItem.ToString()!, Status = ConfirmMode.IsChecked == true ? PrintTaskStatus.AwaitingConfirmation : PrintTaskStatus.Received };
        tasks.Insert(0, task); CountText.Text = tasks.Count.ToString();
        if (SilentMode.IsChecked == true) PrintTask(task);
    }
    private void PreviewTask(object sender, RoutedEventArgs e) { if ((sender as FrameworkElement)?.Tag is PrintTask task) new PreviewWindow(task.FilePath) { Owner = this }.ShowDialog(); }
    private void ConfirmTask(object sender, RoutedEventArgs e) { if ((sender as FrameworkElement)?.Tag is PrintTask task && task.Status == PrintTaskStatus.AwaitingConfirmation) PrintTask(task); }
    private void CancelTask(object sender, RoutedEventArgs e) { if ((sender as FrameworkElement)?.Tag is PrintTask task && task.Status == PrintTaskStatus.AwaitingConfirmation) { task.Status = PrintTaskStatus.Cancelled; _ = PostRemoteEventAsync(task, "cancelled"); } }
    private void PrintTask(PrintTask task) { try { task.Status = PrintTaskStatus.Printing; _ = PostRemoteEventAsync(task, "printing"); printerService.Print(task.FilePath, task.PrinterName); task.Status = PrintTaskStatus.Succeeded; _ = PostRemoteEventAsync(task, "succeeded"); } catch (Exception ex) { task.Status = PrintTaskStatus.Failed; _ = PostRemoteEventAsync(task, "failed", ex.Message); MessageBox.Show(ex.Message, "打印失败"); } }
    private void OpenSettings(object sender, RoutedEventArgs e) { var dialog = new SettingsWindow { Owner = this }; if (dialog.ShowDialog() == true) ApplyPrintBehavior(); }
    private void ApplyPrintBehavior() { var settings = ConnectionSettingsStore.Load(); ConfirmMode.IsChecked = settings.PrintBehavior == PrintBehavior.Confirm; SilentMode.IsChecked = settings.PrintBehavior == PrintBehavior.Silent; }
    private async Task ConnectAndPollAsync(CancellationToken cancellationToken)
    {
        var settings = ConnectionSettingsStore.Load();
        if (string.IsNullOrWhiteSpace(settings.ActivationCode) && string.IsNullOrWhiteSpace(settings.AccessToken)) { DeviceText.Text = "请在接入配置填写 API 地址和注册码"; return; }
        try
        {
            if (string.IsNullOrWhiteSpace(settings.AccessToken) || string.IsNullOrWhiteSpace(settings.DeviceId))
            {
                var registration = await remoteClient.RegisterAsync(settings);
                settings.DeviceId = registration.DeviceId; settings.AccessToken = registration.AccessToken; settings.PollIntervalSeconds = registration.PollIntervalSeconds;
                ConnectionSettingsStore.Save(settings);
            }
            var printers = printerService.GetPrinterNames();
            await remoteClient.SyncPrintersAsync(settings, printers);
            DeviceText.Text = $"已连接：{settings.DeviceName}";
            while (!cancellationToken.IsCancellationRequested)
            {
                foreach (var job in await remoteClient.ClaimAsync(settings, printers)) await ReceiveRemoteJobAsync(settings, job);
                await Task.Delay(TimeSpan.FromSeconds(Math.Max(1, settings.PollIntervalSeconds)), cancellationToken);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex) { DeviceText.Text = "远程服务连接失败"; MessageBox.Show(ex.Message, "远程打印连接"); }
    }
    private async Task ReceiveRemoteJobAsync(ConnectionSettings settings, RemoteJob job)
    {
        try
        {
            var path = await remoteClient.DownloadAsync(job);
            var task = new PrintTask { RemoteTaskId = job.TaskId, FileName = job.File.FileName, FilePath = path, PrinterName = job.PrinterName, Status = settings.PrintBehavior == PrintBehavior.Silent ? PrintTaskStatus.Received : PrintTaskStatus.AwaitingConfirmation };
            tasks.Insert(0, task); CountText.Text = tasks.Count.ToString();
            await PostRemoteEventAsync(task, settings.PrintBehavior == PrintBehavior.Silent ? "received" : "awaiting_confirmation");
            if (settings.PrintBehavior == PrintBehavior.Silent) PrintTask(task);
        }
        catch (Exception ex) { await remoteClient.PostEventAsync(settings, job.TaskId, "failed", ex.Message); }
    }
    private async Task PostRemoteEventAsync(PrintTask task, string status, string? error = null)
    {
        if (string.IsNullOrWhiteSpace(task.RemoteTaskId)) return;
        try { await remoteClient.PostEventAsync(ConnectionSettingsStore.Load(), task.RemoteTaskId, status, error); } catch { }
    }
}
