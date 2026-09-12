using System.Diagnostics;
using System.Windows;
using System.Windows.Media.Imaging;

namespace RemotePrintWindows;

public partial class PreviewWindow : Window
{
    private readonly string filePath;
    private double zoom = 1;

    public PreviewWindow(string filePath)
    {
        InitializeComponent();
        this.filePath = filePath;
        TitleText.Text = Path.GetFileName(filePath);
        if (Path.GetExtension(filePath).Equals(".pdf", StringComparison.OrdinalIgnoreCase)) return;
        PdfPanel.Visibility = Visibility.Collapsed;
        ImageScroll.Visibility = Visibility.Visible;
        PreviewImage.Source = new BitmapImage(new Uri(filePath));
    }

    private void ZoomIn(object sender, RoutedEventArgs e) => SetZoom(zoom + .25);
    private void ZoomOut(object sender, RoutedEventArgs e) => SetZoom(zoom - .25);
    private void SetZoom(double value) { zoom = Math.Clamp(value, .25, 4); ImageScale.ScaleX = zoom; ImageScale.ScaleY = zoom; ZoomText.Text = $"{zoom:P0}"; }
    private void OpenPdf(object sender, RoutedEventArgs e) => Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });
    private void CloseWindow(object sender, RoutedEventArgs e) => Close();
}
