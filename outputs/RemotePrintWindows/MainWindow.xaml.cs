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
    public MainWindow() { InitializeComponent(); LoadPrinters(); TaskList.ItemsSource = tasks; ApplyPrintBehavior(); }
    private void LoadPrinters() { try { foreach (var printer in printerService.GetPrinterNames()) PrinterBox.Items.Add(printer); if (PrinterBox.Items.Count > 0) PrinterBox.SelectedIndex = 0; DeviceText.Text = PrinterBox.SelectedItem?.ToString() ?? "未发现打印机"; } catch (Exception ex) { DeviceText.Text = "读取打印机失败"; MessageBox.Show(ex.Message, "远程打印控制台"); } }
    private void ChooseFile(object sender, RoutedEventArgs e) { var dialog = new OpenFileDialog { Filter = "打印文件|*.pdf;*.jpg;*.jpeg;*.png" }; if (dialog.ShowDialog() == true) { selectedFile = dialog.FileName; FileNameText.Text = System.IO.Path.GetFileName(selectedFile); } }
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
    private void ConfirmTask(object sender, RoutedEventArgs e) { if ((sender as FrameworkElement)?.Tag is PrintTask task) { if (task.Status != PrintTaskStatus.AwaitingConfirmation) return; PrintTask(task); } }
    private void CancelTask(object sender, RoutedEventArgs e) { if ((sender as FrameworkElement)?.Tag is PrintTask task && task.Status == PrintTaskStatus.AwaitingConfirmation) task.Status = PrintTaskStatus.Cancelled; }
    private void PrintTask(PrintTask task) { try { task.Status = PrintTaskStatus.Printing; printerService.Print(task.FilePath, task.PrinterName); task.Status = PrintTaskStatus.Succeeded; } catch (Exception ex) { task.Status = PrintTaskStatus.Failed; MessageBox.Show(ex.Message, "打印失败"); } }
    private void OpenSettings(object sender, RoutedEventArgs e) { var dialog = new SettingsWindow { Owner = this }; if (dialog.ShowDialog() == true) ApplyPrintBehavior(); }
    private void ApplyPrintBehavior() { var settings = ConnectionSettingsStore.Load(); ConfirmMode.IsChecked = settings.PrintBehavior == PrintBehavior.Confirm; SilentMode.IsChecked = settings.PrintBehavior == PrintBehavior.Silent; }
}
