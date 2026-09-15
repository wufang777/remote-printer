using System.Diagnostics;
using System.Printing;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace RemotePrintWindows.Services;

public sealed class PrinterService
{
    public IReadOnlyList<string> GetPrinterNames()
    {
        var server = new LocalPrintServer();
        return server.GetPrintQueues().Select(queue => queue.Name).OrderBy(name => name).ToArray();
    }

    public void Print(string filePath, string printerName)
    {
        var extension = Path.GetExtension(filePath).ToLowerInvariant();
        if (extension is ".jpg" or ".jpeg" or ".png")
        {
            PrintImage(filePath, printerName);
            return;
        }

        if (extension is ".pdf" or ".doc" or ".docx" or ".xls" or ".xlsx" or ".ppt" or ".pptx" or ".csv" or ".wps" or ".et" or ".dps")
        {
            Process.Start(new ProcessStartInfo(filePath, $"\"{printerName}\"")
            {
                Verb = "printto",
                UseShellExecute = true,
                WindowStyle = ProcessWindowStyle.Hidden
            });
            return;
        }

        throw new NotSupportedException("不支持此打印文件格式。");
    }

    private static void PrintImage(string filePath, string printerName)
    {
        var bitmap = new BitmapImage(new Uri(filePath));
        var image = new Image { Source = bitmap, Stretch = Stretch.Uniform };
        image.Measure(new Size(800, 1100));
        image.Arrange(new Rect(new Point(0, 0), image.DesiredSize));

        var dialog = new PrintDialog();
        dialog.PrintQueue = new LocalPrintServer().GetPrintQueue(printerName);
        dialog.PrintVisual(image, Path.GetFileName(filePath));
    }
}
