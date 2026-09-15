using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace RemotePrintWindows.Services;

public sealed class RemoteRelayClient(HttpClient? httpClient = null)
{
    private readonly HttpClient client = httpClient ?? new HttpClient();
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public async Task<RemoteRegistration> RegisterAsync(ConnectionSettings settings)
    {
        var response = await SendAsync<RegisterRequest, RegisterResponse>(settings.ApiBaseUrl, "devices/register", HttpMethod.Post,
            new RegisterRequest(settings.ActivationCode, settings.DeviceName, "Windows", "0.1.0", Environment.OSVersion.VersionString), null);
        return new RemoteRegistration(response.DeviceId, response.AccessToken, Math.Max(1, response.PollIntervalSeconds));
    }

    public async Task SyncPrintersAsync(ConnectionSettings settings, IReadOnlyList<string> printers)
    {
        var entries = printers.Select((name, index) => new PrinterEntry(name, index == 0, true)).ToArray();
        await SendAsync<object, object>(settings.ApiBaseUrl, $"devices/{settings.DeviceId}/printers", HttpMethod.Put, new { printers = entries }, settings.AccessToken);
    }

    public async Task<IReadOnlyList<RemoteJob>> ClaimAsync(ConnectionSettings settings, IReadOnlyList<string> printers)
    {
        var result = await SendAsync<object, ClaimResponse>(settings.ApiBaseUrl, $"devices/{settings.DeviceId}/print-jobs:claim", HttpMethod.Post,
            new { maxJobs = 5, supportedFormats = new[] { "pdf", "image", "office", "wps" }, availablePrinters = printers }, settings.AccessToken);
        return result.Jobs;
    }

    public async Task<string> DownloadAsync(RemoteJob job)
    {
        var data = await client.GetByteArrayAsync(job.File.DownloadUrl);
        var checksum = Convert.ToHexString(SHA256.HashData(data)).ToLowerInvariant();
        if (!string.Equals(checksum, job.File.Sha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("下载文件校验失败。");
        var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "RemotePrintWindows", "jobs");
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, $"{job.TaskId}-{Path.GetFileName(job.File.FileName)}");
        await File.WriteAllBytesAsync(path, data);
        return path;
    }

    public Task PostEventAsync(ConnectionSettings settings, string taskId, string status, string? message = null) =>
        SendAsync<object, object>(settings.ApiBaseUrl, $"devices/{settings.DeviceId}/print-jobs/{taskId}/events", HttpMethod.Post,
            new { status, occurredAt = DateTimeOffset.UtcNow, error = message is null ? null : new { code = "PRINT_FAILED", message, retryable = false } }, settings.AccessToken);

    private async Task<TResponse> SendAsync<TRequest, TResponse>(string baseUrl, string path, HttpMethod method, TRequest body, string? token)
    {
        if (!Uri.TryCreate(baseUrl.TrimEnd('/') + "/" + path, UriKind.Absolute, out var uri)) throw new InvalidOperationException("API 地址无效。");
        using var request = new HttpRequestMessage(method, uri) { Content = new StringContent(JsonSerializer.Serialize(body, Json), Encoding.UTF8, "application/json") };
        if (!string.IsNullOrEmpty(token)) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        if (typeof(TResponse) == typeof(object)) return (TResponse)(object)new object();
        return JsonSerializer.Deserialize<TResponse>(await response.Content.ReadAsStringAsync(), Json) ?? throw new InvalidDataException("服务器响应无效。");
    }
}

public sealed record RemoteRegistration(string DeviceId, string AccessToken, int PollIntervalSeconds);
public sealed record RemoteJob(string TaskId, string PrinterName, RemoteFile File);
public sealed record RemoteFile(string DownloadUrl, string Sha256, string FileName);
file sealed record RegisterRequest(string ActivationCode, string DeviceName, string Platform, string AppVersion, string OsVersion);
file sealed record RegisterResponse(string DeviceId, string AccessToken, int PollIntervalSeconds);
file sealed record ClaimResponse(IReadOnlyList<RemoteJob> Jobs);
file sealed record PrinterEntry(string Name, bool IsDefault, bool IsOnline);
