using System.Text.Json;

namespace RemotePrintWindows.Services;

public enum PrintBehavior { Confirm, Silent }

public sealed class ConnectionSettings
{
    public string ApiBaseUrl { get; set; } = "https://print.example.com/v1";
    public string DeviceName { get; set; } = "本机远程打印终端";
    public string ActivationCode { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string AccessToken { get; set; } = "";
    public int PollIntervalSeconds { get; set; } = 10;
    public PrintBehavior PrintBehavior { get; set; } = PrintBehavior.Confirm;
}

public static class ConnectionSettingsStore
{
    private static readonly string DirectoryPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RemotePrintWindows");
    private static readonly string FilePath = Path.Combine(DirectoryPath, "settings.json");

    public static ConnectionSettings Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return new ConnectionSettings();
            return JsonSerializer.Deserialize<ConnectionSettings>(File.ReadAllText(FilePath)) ?? new ConnectionSettings();
        }
        catch (JsonException) { return new ConnectionSettings(); }
        catch (IOException) { return new ConnectionSettings(); }
    }

    public static void Save(ConnectionSettings settings)
    {
        Directory.CreateDirectory(DirectoryPath);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true }));
    }
}
