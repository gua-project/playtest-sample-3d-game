using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using Gua.Testing;
using Gua.Testing.Godot;
using NUnit.Framework;
using NUnit.Framework.Interfaces;

namespace Facility.Regression;

// Source-scene regression only. GodotSceneTestHost owns process/bridge/cleanup.
// This fixture does not launch exported EXEs, discover scenarios, or implement replay.
[TestFixture, NonParallelizable]
public sealed class SceneRegressionTests
{
    private GodotSceneTestHost host = null!;
    private GuaDiagnosticsSession diagnostics = null!;
    private string output = "", appData = "", root = "";
    private readonly List<object> observations = [];

    [SetUp]
    public async Task StartSourceScene()
    {
        host = null!; diagnostics = null!;
        root = FindRoot();
        output = Path.Combine(root, "artifacts", "source-regression", TestContext.CurrentContext.Test.ID);
        appData = Path.Combine(output, "appdata");
        Directory.CreateDirectory(appData);
        var temporary = Path.Combine(output, "tmp");
        Directory.CreateDirectory(temporary);
        observations.Clear();
        host = GodotSceneTestHost.Load("res://main.tscn", new GodotSceneTestHostOptions
        {
            ProjectPath = root,
            BridgeUrl = "ws://127.0.0.1:18732",
            Headless = true,
            AdditionalArguments = ["--max-fps", "60"],
            EnvironmentVariables = new Dictionary<string, string>
            {
                ["APPDATA"] = appData, ["TEMP"] = temporary, ["TMP"] = temporary,
            },
            StartupResetPolicy = GuaResetPolicy.Strict,
            TeardownResetPolicy = GuaResetPolicy.Strict,
            CaptureDiagnosticsBeforeTeardown = true,
            DiagnosticsTestName = TestContext.CurrentContext.Test.FullName,
            DiagnosticsOutputDirectory = output,
        });
        diagnostics = host.CreateDiagnosticsSession(TestContext.CurrentContext.Test.FullName, output);
        await GuaAssertions.WaitForVisibleAsync(host.Context, "start");
        var version = host.GetVersion();
        Assert.Multiple(() =>
        {
            Assert.That(version.CoreVersion, Is.EqualTo("1.1.2"));
            Assert.That(version.RuntimeVersion, Is.EqualTo("1.1.2"));
            Assert.That(version.GodotPluginVersion, Is.EqualTo("1.1.2"));
        });
    }

    [TearDown]
    public void SaveEvidenceAndDispose()
    {
        if (host is null) return;
        try
        {
            var failed = TestContext.CurrentContext.Result.Outcome.Status == TestStatus.Failed;
            if (failed) diagnostics?.Capture(new AssertionException(TestContext.CurrentContext.Result.Message));
            var evidence = new
            {
                kind = "source-scene-regression", scenario = "facility-r1", seed = 3001,
                test = TestContext.CurrentContext.Test.FullName,
                testBodyOutcome = TestContext.CurrentContext.Result.Outcome.ToString(),
                overallResultAuthority = "NUnit TRX, including GodotSceneTestHost teardown",
                version = host.GetVersion(),
                sourceSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(Path.Combine(root, "game.gd")))).ToLowerInvariant(),
                observations,
                finalUiTree = JsonSerializer.Deserialize<JsonElement>(host.Context.GetUiTreeJson()),
                limitations = new[] { "Not exported EXE E2E", "No rendered/physical-input validation", "No Trace/Recording/Replay qualification" },
            };
            var path = Path.Combine(output, "result.json");
            File.WriteAllText(path, JsonSerializer.Serialize(evidence, new JsonSerializerOptions { WriteIndented = true }));
            TestContext.AddTestAttachment(path);
        }
        finally { host.Dispose(); }
    }

    [Test, Description("S01 / former T01,T03,T07,T08: title, pause, save/load, settings and reset")]
    public async Task StartPauseCheckpointSettingsAndReset()
    {
        await Click("start");
        Assert.That(Text("status"), Does.Contain("A:false B:false"));
        var before = Position();
        await Click("pause"); await Click("save"); await Click("resume");
        await Click("forward"); await Task.Delay(300);
        Assert.That(Position().Z, Is.LessThan(before.Z - .5));
        await Click("pause"); await Click("load");
        Assert.That(Screen(), Is.EqualTo("play"));
        Assert.That(Position().Z, Is.EqualTo(before.Z).Within(.05));
        await Click("pause"); await Click("language"); await Click("resize"); await Click("save");
        var saved = JsonNode.Parse(File.ReadAllText(SavePath()))!;
        Assert.That(saved["language"]!.GetValue<string>(), Is.EqualTo("en"));
        Assert.That(saved["window"]![0]!.GetValue<int>(), Is.EqualTo(960));
        var valid = File.ReadAllText(SavePath());
        File.WriteAllText(SavePath(), "{\"broken\":");
        observations.Add(new { testSetup = "deliberately malformed checkpoint, not a gameplay action" });
        await Click("load"); Assert.That(Screen(), Is.EqualTo("pause"));
        Assert.That(Text("menu_message"), Does.Contain("No valid"));
        File.WriteAllText(SavePath(), valid);
        observations.Add(new { testSetup = "restore unchanged valid checkpoint after malformed-input assertion" });
        await Click("load"); Assert.That(Screen(), Is.EqualTo("play"));
        await Click("pause");
        await Click("reset");
        Assert.That(Screen(), Is.EqualTo("play"));
        Assert.That(Text("status"), Does.Contain("A:false B:false").And.Not.Contain("key"));
    }

    [TestCase("tool", -3, 5), TestCase("battery", 3, 5), TestCase("key", -8, -2)]
    [Description("S06 / former T02: ordinary pickup is single-use; repeat interaction never duplicates an item")]
    public async Task PickupIsNotDuplicated(string item, int x, int z)
    {
        await LoadCheckpoint(data =>
        {
            data["position"] = new JsonArray(x, .025, z + 1.5);
            data["yaw"] = 0; data["pitch"] = -20 * Math.PI / 180;
            data["inventory"] = new JsonArray(); data["collected"] = new JsonArray();
            data["generator"] = false; data["auxiliary"] = false;
        });
        Assert.That(Text("target"), Does.Contain(item));
        await Click("interact"); await Click("interact");
        await Click("pause"); await Click("save");
        var saved = JsonNode.Parse(File.ReadAllText(SavePath()))!;
        Assert.That(saved["inventory"]!.AsArray().Count(n => n!.GetValue<string>() == item), Is.EqualTo(1));
        Assert.That(saved["collected"]!.AsArray().Count(n => n!.GetValue<string>() == item), Is.EqualTo(1));
    }

    [TestCase(false), TestCase(true)]
    [Description("S02 / former T03,T09: key retention and individually enabled lost_key detection")]
    public async Task CardRetentionAndLostKeyMutation(bool mutant)
    {
        await LoadCheckpoint(_ => { });
        Assert.That(Text("status"), Does.Contain("key"));
        await Click("pause");
        if (mutant) await Click("bug_lost_key");
        await Click("save"); await Click("load");
        Assert.That(Screen(), Is.EqualTo("play"));
        Assert.That(Text("status").Contains("key"), Is.EqualTo(!mutant), "lost_key must violate retention only when individually enabled");
    }

    [TestCase(false, false), TestCase(true, false), TestCase(false, true), TestCase(true, true)]
    [Description("S03 / former T10: independent far/near expectations; only through_wall bypasses occlusion")]
    public async Task RangeAndOcclusion(bool mutant, bool near)
    {
        await LoadCheckpoint(data =>
        {
            data["position"] = new JsonArray(6, .025, near ? -5.2 : -3.5);
            data["yaw"] = 0; data["pitch"] = -15 * Math.PI / 180;
            data["inventory"] = new JsonArray("battery"); data["collected"] = new JsonArray("battery");
            data["generator"] = false; data["auxiliary"] = false;
            data["bugs"] = mutant ? new JsonArray("through_wall") : new JsonArray();
        });
        Assert.That(Text("status"), Does.Contain("battery"));
        await Click("interact");
        var expectedActivation = mutant && near;
        Assert.That(Text("status").Contains("A:true"), Is.EqualTo(expectedActivation));
        Assert.That(Text("status").Contains("battery"), Is.EqualTo(!expectedActivation));
    }

    [TestCase(false), TestCase(true)]
    [Description("S04 / former T11: occupancy safety and individual door_jam failure detection")]
    public async Task DoorOccupancyAndJamMutation(bool mutant)
    {
        await LoadCheckpoint(data =>
        {
            data["position"] = new JsonArray(6, .025, -11.5);
            data["yaw"] = 0; data["pitch"] = 0;
            data["door_open"] = true; data["door_timer"] = .3;
            data["bugs"] = mutant ? new JsonArray("door_jam") : new JsonArray();
        });
        await Task.Delay(550);
        var before = Position();
        await Click("right"); await Task.Delay(300);
        Assert.That(Position().X - before.X > .5, Is.EqualTo(!mutant), "normal occupancy must allow escape; mutant must be detected as immobile");
    }

    [Test, Description("S05 / former T12: low ceiling blocks standing; crouch permits passage")]
    public async Task LowCeilingCrouchBoundary()
    {
        await LoadCheckpoint(data =>
        {
            data["position"] = new JsonArray(-11, .025, 8);
            data["yaw"] = 0; data["pitch"] = 0;
        });
        await Walk("left", 3);
        Assert.That(Position().X, Is.GreaterThan(-11.8));
        await Walk("forward", 3);
        Assert.That(Position().Z, Is.GreaterThan(7));
        await Click("crouch"); await Walk("forward", 7);
        Assert.That(Position().Z, Is.LessThan(5));
        await Click("crouch");
        Assert.That(Text("status"), Does.Contain("CROUCH"));
    }

    private async Task LoadCheckpoint(Action<JsonObject> arrange)
    {
        var data = JsonNode.Parse(File.ReadAllText(Path.Combine(root, "tests", "fixtures", "upper-checkpoint.json")))!.AsObject();
        arrange(data);
        Directory.CreateDirectory(Path.GetDirectoryName(SavePath())!);
        var prepared = data.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(SavePath(), prepared);
        observations.Add(new { testSetup = "authored checkpoint precondition, not a player action or E2E proof", state = JsonSerializer.Deserialize<JsonElement>(prepared) });
        await Click("load");
        Assert.That(Screen(), Is.EqualTo("play"));
    }

    private async Task Click(string id)
    {
        await GuaAssertions.Query(host.Context).ById(id).ClickAsync();
        var completedFrame = JsonNode.Parse(host.Context.GetUiTreeJson())!["frameSequence"]!.GetValue<long>();
        await GuaAssertions.WaitUntilAsync(
            () => JsonNode.Parse(host.Context.GetUiTreeJson())!["frameSequence"]!.GetValue<long>() > completedFrame,
            "source scene publishes a fresh frame after correlated completion",
            TimeSpan.FromSeconds(3), TimeSpan.FromMilliseconds(10));
        observations.Add(new { action = id, uiTree = JsonSerializer.Deserialize<JsonElement>(host.Context.GetUiTreeJson()) });
    }
    private async Task Walk(string id, int count)
    {
        for (var i = 0; i < count; i++) { await Click(id); await Task.Delay(285); }
    }
    private string Screen() => JsonNode.Parse(host.Context.GetUiTreeJson())!["screen"]!.GetValue<string>();
    private string Text(string id)
    {
        var node = JsonNode.Parse(host.Context.GetUiTreeJson())!["nodes"]!.AsArray().Single(n => n!["id"]!.GetValue<string>() == id)!;
        Assert.That(node["visible"]!.GetValue<bool>(), Is.True, "never assert stale hidden HUD text");
        return node["text"]?.GetValue<string>() ?? "";
    }
    private (double X, double Z) Position()
    {
        Assert.That(Screen(), Is.EqualTo("play"));
        var match = Regex.Match(Text("target"), @"xyz=\(([-\d.]+),([-\d.]+),([-\d.]+)\)");
        Assert.That(match.Success, Is.True);
        return (double.Parse(match.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture), double.Parse(match.Groups[3].Value, System.Globalization.CultureInfo.InvariantCulture));
    }
    private string SavePath() => Path.Combine(appData, "facility-escape-3d", "checkpoint.json");
    private static string FindRoot()
    {
        var directory = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "project.godot"))) directory = directory.Parent;
        return directory?.FullName ?? throw new DirectoryNotFoundException("project.godot not found");
    }
}
