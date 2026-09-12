using RemotePrintWindows.Services;

namespace RemotePrintWindows.Tests;

public sealed class ConnectionSettingsTests
{
    [Fact]
    public void Defaults_provide_a_named_device_and_confirmation_mode()
    {
        var settings = new ConnectionSettings();

        Assert.Equal("本机远程打印终端", settings.DeviceName);
        Assert.Equal(PrintBehavior.Confirm, settings.PrintBehavior);
    }
}
