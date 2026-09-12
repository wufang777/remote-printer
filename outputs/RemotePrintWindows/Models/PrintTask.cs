using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace RemotePrintWindows.Models;
public enum PrintTaskStatus { Received, AwaitingConfirmation, Printing, Succeeded, Failed, Cancelled }
public sealed class PrintTask : INotifyPropertyChanged
{
    private PrintTaskStatus status = PrintTaskStatus.Received;
    public string FileName { get; init; } = "";
    public string FilePath { get; init; } = "";
    public string PrinterName { get; init; } = "";
    public PrintTaskStatus Status { get => status; set { status = value; OnPropertyChanged(); OnPropertyChanged(nameof(StatusLabel)); } }
    public string StatusLabel => Status switch { PrintTaskStatus.AwaitingConfirmation => "等待确认", PrintTaskStatus.Printing => "正在打印", PrintTaskStatus.Succeeded => "打印已提交", PrintTaskStatus.Failed => "打印失败", PrintTaskStatus.Cancelled => "已取消", _ => "已接收" };
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
