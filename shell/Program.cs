using System;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace YaoguaiNightMarket
{
    internal static class Program
    {
        private const string PayloadResource = "YaoguaiNightMarket.payload.zip";
        private static string payloadRoot;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool SetDllDirectory(string path);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string path);

        [STAThread]
        private static void Main(string[] args)
        {
            try
            {
                payloadRoot = EnsurePayload();
                AppDomain.CurrentDomain.AssemblyResolve += ResolveEmbeddedAssembly;
                SetDllDirectory(payloadRoot);
                LoadLibrary(Path.Combine(payloadRoot, "WebView2Loader.dll"));
                Run(args);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Startup failed.\r\n\r\n" + ex.Message,
                    "\u5996\u602A\u591C\u5E02 v" + BuildInfo.Version,
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }

        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void Run(string[] args)
        {
            bool debug = false;
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--debug")
                {
                    debug = true;
                }
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new GameWindow(debug, payloadRoot));
        }

        private static string EnsurePayload()
        {
            string root = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "YaoguaiNightMarket",
                "runtime",
                "v" + BuildInfo.Version + "_" + BuildInfo.Revision);
            string www = Path.Combine(root, "www", "index.html");
            string core = Path.Combine(root, "Microsoft.Web.WebView2.Core.dll");
            string winforms = Path.Combine(root, "Microsoft.Web.WebView2.WinForms.dll");
            string loader = Path.Combine(root, "WebView2Loader.dll");
            string marker = Path.Combine(root, ".payload-ok");

            if (File.Exists(marker) && File.Exists(www) && File.Exists(core) && File.Exists(winforms) && File.Exists(loader))
            {
                return root;
            }

            try
            {
                if (Directory.Exists(root))
                {
                    Directory.Delete(root, true);
                }
            }
            catch
            {
            }
            Directory.CreateDirectory(root);

            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResource))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("Embedded payload is missing.");
                }
                using (ZipArchive archive = new ZipArchive(stream, ZipArchiveMode.Read))
                {
                    string rootPrefix = Path.GetFullPath(root) + Path.DirectorySeparatorChar;
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string dest = Path.GetFullPath(Path.Combine(root, entry.FullName));
                        if (!dest.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase))
                        {
                            throw new InvalidOperationException("Invalid payload path.");
                        }
                        if (string.IsNullOrEmpty(entry.Name))
                        {
                            Directory.CreateDirectory(dest);
                            continue;
                        }
                        string parent = Path.GetDirectoryName(dest);
                        if (!string.IsNullOrEmpty(parent))
                        {
                            Directory.CreateDirectory(parent);
                        }
                        using (Stream input = entry.Open())
                        using (FileStream output = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            input.CopyTo(output);
                        }
                    }
                }
            }

            File.WriteAllText(marker, BuildInfo.Version + "\n" + BuildInfo.Revision + "\n");
            if (!File.Exists(www) || !File.Exists(core) || !File.Exists(winforms) || !File.Exists(loader))
            {
                throw new InvalidOperationException("Embedded payload is incomplete.");
            }
            return root;
        }

        private static Assembly ResolveEmbeddedAssembly(object sender, ResolveEventArgs args)
        {
            try
            {
                string name = new AssemblyName(args.Name).Name;
                string path = Path.Combine(payloadRoot, name + ".dll");
                if (File.Exists(path))
                {
                    return Assembly.LoadFrom(path);
                }
            }
            catch
            {
            }
            return null;
        }
    }

    internal sealed class GameWindow : Form
    {
        private readonly WebView2 web;
        private readonly MenuStrip menu;
        private readonly Panel content;
        private readonly bool debug;
        private readonly string payloadRoot;

        public GameWindow(bool debug, string payloadRoot)
        {
            this.debug = debug;
            this.payloadRoot = payloadRoot;

            Text = "\u5996\u602A\u591C\u5E02 v" + BuildInfo.Version;
            BackColor = Color.FromArgb(13, 15, 24);
            StartPosition = FormStartPosition.CenterScreen;
            MinimumSize = new Size(960, 640);

            Rectangle area = Screen.PrimaryScreen.WorkingArea;
            int width = Math.Min(1700, (int)(area.Width * 0.92));
            int height = Math.Min(1050, (int)(area.Height * 0.92));
            ClientSize = new Size(width, height);

            try
            {
                Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            }
            catch
            {
            }

            menu = new MenuStrip();
            menu.Dock = DockStyle.Top;
            ToolStripMenuItem gameMenu = new ToolStripMenuItem("\u6E38\u620F");

            ToolStripMenuItem reloadItem = new ToolStripMenuItem("\u91CD\u65B0\u52A0\u8F7D");
            reloadItem.ShortcutKeys = Keys.F5;
            reloadItem.Click += delegate { ReloadPage(); };
            gameMenu.DropDownItems.Add(reloadItem);

            ToolStripMenuItem devToolsItem = new ToolStripMenuItem("\u5F00\u53D1\u8005\u5DE5\u5177");
            devToolsItem.ShortcutKeys = Keys.F12;
            devToolsItem.Click += delegate { OpenDevTools(); };
            gameMenu.DropDownItems.Add(devToolsItem);
            gameMenu.DropDownItems.Add(new ToolStripSeparator());

            ToolStripMenuItem exitItem = new ToolStripMenuItem("\u9000\u51FA");
            exitItem.Click += delegate { Close(); };
            gameMenu.DropDownItems.Add(exitItem);

            menu.Items.Add(gameMenu);
            MainMenuStrip = menu;

            web = new WebView2();
            web.Dock = DockStyle.Fill;
            web.DefaultBackgroundColor = Color.FromArgb(13, 15, 24);

            content = new Panel();
            content.BackColor = Color.FromArgb(13, 15, 24);
            content.Controls.Add(web);

            Controls.Add(content);
            Controls.Add(menu);
            menu.BringToFront();

            ClientSizeChanged += delegate { LayoutContent(); };
            Shown += delegate { LayoutContent(); };
            LayoutContent();

            Load += OnLoaded;
            FormClosing += OnClosing;
        }

        private void LayoutContent()
        {
            int top = menu.Height;
            content.SetBounds(
                0,
                top,
                ClientSize.Width,
                Math.Max(0, ClientSize.Height - top));
        }

        private async void ReloadPage()
        {
            if (web.CoreWebView2 == null)
            {
                return;
            }
            try
            {
                await web.CoreWebView2.CallDevToolsProtocolMethodAsync(
                    "Page.reload",
                    "{\"ignoreCache\":true}");
            }
            catch
            {
            }
        }

        private void OpenDevTools()
        {
            if (web.CoreWebView2 != null)
            {
                web.CoreWebView2.OpenDevToolsWindow();
            }
        }

        private async void OnLoaded(object sender, EventArgs e)
        {
            try
            {
                string www = Path.Combine(payloadRoot, "www");
                string data = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "YaoguaiNightMarket",
                    "WebView2");
                Directory.CreateDirectory(data);

                string arguments = "--autoplay-policy=no-user-gesture-required";
                if (debug)
                {
                    arguments += " --remote-debugging-port=9224 --remote-allow-origins=*";
                }
                CoreWebView2EnvironmentOptions options = new CoreWebView2EnvironmentOptions(arguments, null, null, false, null);
                CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(null, data, options);
                if (IsDisposed)
                {
                    return;
                }
                await web.EnsureCoreWebView2Async(environment);
                if (IsDisposed)
                {
                    return;
                }

                CoreWebView2 core = web.CoreWebView2;
                core.Settings.AreDevToolsEnabled = true;
                core.Settings.AreDefaultContextMenusEnabled = true;
                core.Settings.IsStatusBarEnabled = false;
                core.Settings.AreBrowserAcceleratorKeysEnabled = true;
                core.Settings.IsBuiltInErrorPageEnabled = true;

                try
                {
                    await core.CallDevToolsProtocolMethodAsync("Network.enable", "{}");
                    await core.CallDevToolsProtocolMethodAsync("Network.setCacheDisabled", "{\"cacheDisabled\":true}");
                }
                catch
                {
                }

                core.SetVirtualHostNameToFolderMapping(
                    "yaoguai.local",
                    www,
                    CoreWebView2HostResourceAccessKind.Allow);
                core.Navigate("https://yaoguai.local/index.html");
            }
            catch (Exception ex)
            {
                if (!IsDisposed)
                {
                    MessageBox.Show(
                        "WebView2 failed to start.\r\n\r\nPlease install Microsoft Edge WebView2 Runtime.\r\n\r\n" + ex.Message,
                        Text,
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    Close();
                }
            }
        }

        private void OnClosing(object sender, FormClosingEventArgs e)
        {
            try
            {
                web.Dispose();
            }
            catch
            {
            }
        }
    }
}
