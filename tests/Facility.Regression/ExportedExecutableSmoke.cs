using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using System.Globalization;
using Gua.Core;
using Gua.Testing;
using Gua.Testing.Godot;
using NUnit.Framework;

namespace Facility.Regression;

// A bounded distribution development check, not a Scenario/exploration/Replay runner.
public sealed class ExportedExecutableSmoke
{
    [Test, Explicit("Requires a freshly built Windows package; select this test by name")]
    public async Task ConnectStartAndMove()
    {
        var root = Path.GetFullPath(Path.Combine(TestContext.CurrentContext.TestDirectory, "../../../../../"));
        var output = Path.Combine(root, "artifacts", "package-protocol-smoke", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(output);
        var staging = Path.Combine(output, "package");
        Directory.CreateDirectory(staging);
        foreach (var name in new[] { "FacilityEscape.exe", "gua_godot.windows.release.x86_64.dll" })
            File.Copy(Path.Combine(root, "dist", name), Path.Combine(staging, name), true);
        var nativeInfo = JsonNode.Parse(GuaBuildInfo.GetJson())!;
        Assert.That(nativeInfo["flavor"]!.GetValue<string>(), Is.EqualTo("development"));
        Assert.That(nativeInfo["remoteEnabled"]!.GetValue<bool>(), Is.True);
        Assert.That(nativeInfo["remotePermissionCeiling"]!.GetValue<string>(), Is.EqualTo("debug"));
        Assert.That(nativeInfo["sourceCommit"]!.GetValue<string>(), Is.EqualTo("2e12fb3cfdf822418f349515027d6f620c5ee63b"));
        var nativeRoot = Path.Combine(root, "vendor", "nuget", "gua.core", "1.2.0", "runtimes", "win-x64", "native");
        var manifest = JsonNode.Parse(File.ReadAllText(Path.Combine(nativeRoot, "gua-core-build-manifest.json")))!;
        Assert.That(manifest["build"]!.ToJsonString(), Is.EqualTo(nativeInfo.ToJsonString()));
        var coreEntry = manifest["files"]!.AsArray().Single(entry => entry!["path"]!.GetValue<string>() == "gua.dll")!;
        Assert.That(Hash(Path.Combine(nativeRoot, "gua.dll")), Is.EqualTo(coreEntry["sha256"]!.GetValue<string>()));
        var start = new ProcessStartInfo(Path.Combine(staging, "FacilityEscape.exe"))
        {
            WorkingDirectory = staging, UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true,
        };
        start.ArgumentList.Add("--headless"); start.ArgumentList.Add("--max-fps"); start.ArgumentList.Add("60");
        var appdata = Path.Combine(output, "appdata"); Directory.CreateDirectory(appdata);
        start.Environment["APPDATA"] = appdata;
        var temporary = Path.Combine(output, "tmp"); Directory.CreateDirectory(temporary);
        start.Environment["TEMP"] = temporary; start.Environment["TMP"] = temporary;
        start.Environment["GUA_BRIDGE_PORT"] = "18743";
        start.Environment["GUA_NATIVE_DIR"] = ""; start.Environment["GUA_RUNTIME_NATIVE_DIR"] = "";
        using var process = Process.Start(start)!;
        var stdout = process.StandardOutput.ReadToEndAsync(); var stderr = process.StandardError.ReadToEndAsync();
        using var context = new GuaRemoteContext("ws://127.0.0.1:18743", TimeSpan.FromSeconds(5));
        try
        {
            await GuaAssertions.WaitForVisibleAsync(context, "start", TimeSpan.FromSeconds(10), TimeSpan.FromMilliseconds(50));
            var version = context.GetVersion();
            Assert.That(version.CoreVersion, Is.EqualTo("1.2.0"));
            Assert.That(version.BuildId, Is.EqualTo("2e12fb3cfdf822418f349515027d6f620c5ee63b"));
            await GuaAssertions.Query(context).ById("start").ClickAsync(timeout: TimeSpan.FromSeconds(5));
            await GuaAssertions.WaitUntilAsync(() => Tree()["screen"]!.GetValue<string>() == "play", "ordinary start", TimeSpan.FromSeconds(3));
            var before = Z();
            await GuaAssertions.Query(context).ById("forward").ClickAsync(timeout: TimeSpan.FromSeconds(5));
            await GuaAssertions.WaitUntilAsync(() => Z() < before - 0.2, "ordinary forward input decreases observed Z", TimeSpan.FromSeconds(3));
            var after = Z();
            Assert.That(context.Reset(new GuaResetOptions(Strict: true)).Result, Is.EqualTo(GuaResetResult.Succeeded));
            File.WriteAllText(Path.Combine(output, "result.json"), new JsonObject
            {
                ["scope"] = "limited development EXE connect/start/forward only; not Playtest E2E",
                ["nativeBuildInfo"] = nativeInfo.DeepClone(), ["nativeManifest"] = manifest.DeepClone(),
                ["manifestVerificationScope"] = "Core gua.dll hash only; runtime/LICENSE pair entries are not shipped in Core native folder",
                ["exeSha256"] = Hash(start.FileName), ["dllSha256"] = Hash(Path.Combine(staging, "gua_godot.windows.release.x86_64.dll")),
                ["before"] = before, ["after"] = after, ["port"] = 18743,
                ["authority"] = "NUnit TRX including cleanup; this JSON is not the overall pass result",
            }.ToJsonString());
        }
        finally
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
            Assert.That(process.WaitForExit(5000), Is.True, "owned EXE cleanup");
            File.WriteAllText(Path.Combine(output, "stdout.txt"), await stdout);
            File.WriteAllText(Path.Combine(output, "stderr.txt"), await stderr);
        }
        JsonNode Tree() => JsonNode.Parse(context.GetUiTreeJson())!;
        double Z()
        {
            var target = Tree()["nodes"]!.AsArray().Single(n => n!["id"]!.GetValue<string>() == "target")!["text"]!.GetValue<string>();
            var match = Regex.Match(target, @"xyz=\(([-\d.]+),([-\d.]+),([-\d.]+)\)");
            Assert.That(match.Success, Is.True);
            return double.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture);
        }
    }
    private static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
}
