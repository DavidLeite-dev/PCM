using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

class BookSwapLauncher
{
    private static readonly string ApiPath = @"C:\Users\david\Documents\PCM\BookSwapAPI";
    private static readonly string NgrokPath = @"C:\Users\david\Documents\PCM\ngrok.exe";
    private static readonly int ApiPort = 5003;
    private static readonly string SqlServer = ".";
    private static readonly string Database = "BookSwap";
    private static Process apiProcess = null;
    private static Process ngrokProcess = null;

    static async Task Main()
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("╔════════════════════════════════════╗");
        Console.WriteLine("║    BookSwap Server Manager         ║");
        Console.WriteLine("╚════════════════════════════════════╝\n");
        Console.ResetColor();

        ShowMainMenu();
    }

    static void ShowMainMenu()
    {
        while (true)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("╔═══════════════════════════════════╗");
            Console.WriteLine("║       Server Manager Menu         ║");
            Console.WriteLine("╠═══════════════════════════════════╣");
            Console.WriteLine("║ 1. Start API                      ║");
            Console.WriteLine("║ 2. Start SQL Server               ║");
            Console.WriteLine("║ 3. Start ngrok                    ║");
            Console.WriteLine("║ 4. Stop API                       ║");
            Console.WriteLine("║ 5. Stop SQL Server                ║");
            Console.WriteLine("║ 6. Stop ngrok                     ║");
            Console.WriteLine("║ 7. Check All Statuses             ║");
            Console.WriteLine("║ 8. View API Logs                  ║");
            Console.WriteLine("║ 9. View ngrok Logs                ║");
            Console.WriteLine("║ 0. Exit                           ║");
            Console.WriteLine("╚═══════════════════════════════════╝");
            Console.ResetColor();

            Console.Write("\n👉 Select option (0-9): ");
            string choice = Console.ReadLine();

            switch (choice)
            {
                case "1":
                    StartApiCommand();
                    break;
                case "2":
                    StartSqlServerCommand();
                    break;
                case "3":
                    StartNgrokCommand();
                    break;
                case "4":
                    StopApi();
                    break;
                case "5":
                    StopSqlServer();
                    break;
                case "6":
                    StopNgrok();
                    break;
                case "7":
                    CheckAllStatuses();
                    break;
                case "8":
                    ViewApiLogs();
                    break;
                case "9":
                    ViewNgrokLogs();
                    break;
                case "0":
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("\n👋 Exiting...");
                    Console.ResetColor();
                    return;
                default:
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("❌ Invalid option. Please try again.");
                    Console.ResetColor();
                    break;
            }
        }
    }

    static void StartApiCommand()
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("📋 Opening API in new terminal...\n");
        Console.ResetColor();

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-NoExit -Command \"cd '{ApiPath}'; Write-Host 'Starting BookSwap API...' -ForegroundColor Cyan; dotnet run --configuration Development\"",
                UseShellExecute = true
            };

            Process.Start(psi);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ API terminal opened - logs visible in new window");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error opening API terminal: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void StartSqlServerCommand()
    {
        Console.WriteLine();
        if (CheckSqlServer())
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ SQL Server is already running");
            Console.ResetColor();
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.Write("🚀 Starting SQL Server... ");
        Console.ResetColor();

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "net",
                Arguments = "start MSSQLSERVER",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using (Process process = Process.Start(psi))
            {
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                
                System.Threading.Thread.Sleep(2000); // Give SQL Server time to fully start
                
                if (CheckSqlServer())
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("✅ SQL Server started successfully");
                    Console.ResetColor();
                }
                else if (process.ExitCode == 2)
                {
                    // SQL Server service not found - likely not installed
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("❌ SQL Server service not found");
                    Console.WriteLine("   (SQL Server may not be installed)");
                    Console.ResetColor();
                }
                else if (process.ExitCode == 5)
                {
                    // Access denied - need admin privileges
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("❌ Access denied");
                    Console.WriteLine("   (Launcher requires admin privileges)");
                    Console.ResetColor();
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("❌ Failed to start SQL Server");
                    Console.ResetColor();
                }
            }
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void StartNgrokCommand()
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("📋 Opening ngrok in new terminal...\n");
        Console.ResetColor();

        try
        {
            string ngrokDir = Path.GetDirectoryName(NgrokPath);
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-NoExit -Command \"cd '{ngrokDir}'; Write-Host 'Starting ngrok tunnel on port {ApiPort}...' -ForegroundColor Cyan; .\\\\ngrok.exe http {ApiPort}\"",
                UseShellExecute = true
            };

            Process.Start(psi);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ ngrok terminal opened - logs visible in new window");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error opening ngrok terminal: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void StopApi()
    {
        Console.WriteLine();
        if (!IsApiRunning())
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠️  API is not running");
            Console.ResetColor();
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.Write("🛑 Stopping API on port {0}... ", ApiPort);
        Console.ResetColor();
        
        KillProcessByPort(ApiPort);
        System.Threading.Thread.Sleep(2000);

        if (!IsApiRunning())
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ API stopped");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("❌ Failed to stop API");
            Console.ResetColor();
        }
    }

    static void StopSqlServer()
    {
        Console.WriteLine();
        if (!CheckSqlServer())
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠️  SQL Server is not running");
            Console.ResetColor();
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.Write("🛑 Stopping SQL Server... ");
        Console.ResetColor();

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "net",
                Arguments = "stop MSSQLSERVER",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using (Process process = Process.Start(psi))
            {
                process.WaitForExit();
                System.Threading.Thread.Sleep(1000); // Give SQL Server time to fully stop
                
                if (!CheckSqlServer())
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("✅ SQL Server stopped");
                    Console.ResetColor();
                }
                else if (process.ExitCode == 0)
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("✅ SQL Server stopped");
                    Console.ResetColor();
                }
                else if (process.ExitCode == 5)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("❌ Access denied - requires admin privileges");
                    Console.ResetColor();
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("⚠️  Could not stop SQL Server");
                    Console.ResetColor();
                }
            }
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void StopNgrok()
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.Write("🛑 Stopping ngrok... ");
        Console.ResetColor();

        try
        {
            // Kill ngrok.exe process by name
            var ngrokProcesses = Process.GetProcessesByName("ngrok");
            foreach (var process in ngrokProcesses)
            {
                try
                {
                    process.Kill();
                    process.WaitForExit(2000);
                }
                catch { }
            }
            
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ ngrok stopped");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void CheckAllStatuses()
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("╔═════════════════════════════════════╗");
        Console.WriteLine("║        System Status Check          ║");
        Console.WriteLine("╚═════════════════════════════════════╝\n");
        Console.ResetColor();

        // Check SQL Server
        Console.Write("🔍 SQL Server:\n");
        if (CheckSqlServer())
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("   ✅ Running");
            Console.WriteLine("   📍 Server: localhost");
            Console.WriteLine("   🔌 Database: BookSwap");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("   ❌ Stopped");
            Console.ResetColor();
        }

        Console.WriteLine();

        // Check API
        Console.Write("🔍 API:\n");
        if (IsApiRunning())
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("   ✅ Running");
            Console.WriteLine($"   📍 Localhost: http://localhost:{ApiPort}/api");
            Console.WriteLine($"   🌐 IP: {GetLocalIpAddress()}:{ApiPort}");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("   ❌ Stopped");
            Console.ResetColor();
        }

        Console.WriteLine();

        // Check ngrok
        Console.Write("🔍 ngrok tunnel:\n");
        if (IsNgrokRunning())
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("   ✅ Running");
            string url = GetNgrokUrl();
            if (!string.IsNullOrEmpty(url))
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine($"   🌐 Public URL: {url}/api");
            }
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("   ❌ Stopped");
            Console.ResetColor();
        }
    }

    static void ViewApiLogs()
    {
        Console.WriteLine();
        
        if (!IsApiRunning())
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠️  API is not running");
            Console.WriteLine("   Select option 1 to start the API first");
            Console.ResetColor();
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("📋 API is running. Opening monitoring terminal...\n");
        Console.ResetColor();

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-NoExit -Command \"Write-Host '═══════════════════════════════════════════════════' -ForegroundColor Cyan; Write-Host 'BookSwap API Monitor' -ForegroundColor Green; Write-Host '═══════════════════════════════════════════════════' -ForegroundColor Cyan; Write-Host ''; Write-Host 'API Status: RUNNING' -ForegroundColor Green; Write-Host \\\"Port: {ApiPort}\\\" -ForegroundColor Cyan; Write-Host \\\"Local: http://127.0.0.1:{ApiPort}/api\\\" -ForegroundColor Cyan; Write-Host \\\"IP: http://{GetLocalIpAddress()}:{ApiPort}/api\\\" -ForegroundColor Cyan; Write-Host ''; Write-Host 'API process is running in another terminal.' -ForegroundColor Yellow; Write-Host 'You can use this window to monitor or perform other tasks.' -ForegroundColor Yellow; Write-Host ''; while (\\\\\\$true) {{ Start-Sleep -Seconds 5 }}\"",
                UseShellExecute = true
            };

            Process.Start(psi);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ Monitoring terminal opened");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error opening monitoring terminal: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void ViewNgrokLogs()
    {
        Console.WriteLine();
        
        if (!IsNgrokRunning())
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠️  ngrok is not running");
            Console.WriteLine("   Select option 3 to start ngrok first");
            Console.ResetColor();
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("📋 ngrok is running. Opening monitoring terminal...\n");
        Console.ResetColor();

        try
        {
            string ngrokUrl = GetNgrokUrl();
            string urlInfo = string.IsNullOrEmpty(ngrokUrl) ? "(fetching URL...)" : ngrokUrl;
            
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-NoExit -Command \"Write-Host '═══════════════════════════════════════════════════' -ForegroundColor Cyan; Write-Host 'ngrok Tunnel Monitor' -ForegroundColor Green; Write-Host '═══════════════════════════════════════════════════' -ForegroundColor Cyan; Write-Host ''; Write-Host 'ngrok Status: RUNNING' -ForegroundColor Green; Write-Host \\\"Port: {ApiPort}\\\" -ForegroundColor Cyan; Write-Host \\\"Public URL: {urlInfo}\\\" -ForegroundColor Cyan; Write-Host 'Dashboard: http://localhost:4040' -ForegroundColor Cyan; Write-Host ''; Write-Host 'ngrok process is running in another terminal.' -ForegroundColor Yellow; Write-Host 'You can use this window to monitor or perform other tasks.' -ForegroundColor Yellow; Write-Host ''; while (\\\\\\$true) {{ Start-Sleep -Seconds 5 }}\"",
                UseShellExecute = true
            };

            Process.Start(psi);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ Monitoring terminal opened");
            Console.ResetColor();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"❌ Error opening monitoring terminal: {ex.Message}");
            Console.ResetColor();
        }
    }

    static string GetLocalIpAddress()
    {
        try
        {
            using (var socket = new System.Net.Sockets.Socket(
                System.Net.Sockets.AddressFamily.InterNetwork,
                System.Net.Sockets.SocketType.Dgram, 0))
            {
                socket.Connect("8.8.8.8", 65530);
                var endPoint = socket.LocalEndPoint as System.Net.IPEndPoint;
                return endPoint?.Address.ToString() ?? "127.0.0.1";
            }
        }
        catch
        {
            return "127.0.0.1";
        }
    }


    static bool CheckSqlServer()
    {
        try
        {
            // Try connecting to BookSwap database first
            string connectionString = $"Server={SqlServer};Database={Database};Trusted_Connection=True;Connection Timeout=2;";
            using (var connection = new System.Data.SqlClient.SqlConnection(connectionString))
            {
                connection.Open();
                return true;
            }
        }
        catch
        {
            // Fallback: try connecting to master database
            try
            {
                string fallbackConnectionString = $"Server={SqlServer};Database=master;Trusted_Connection=True;Connection Timeout=2;";
                using (var connection = new System.Data.SqlClient.SqlConnection(fallbackConnectionString))
                {
                    connection.Open();
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }
    }

    static bool IsApiRunning()
    {
        try
        {
            // Use TCP connect to check if API is listening on the port
            using (var tcpClient = new System.Net.Sockets.TcpClient())
            {
                var result = tcpClient.BeginConnect("127.0.0.1", ApiPort, null, null);
                bool success = result.AsyncWaitHandle.WaitOne(3000, true); // 3 second timeout
                
                if (!success)
                {
                    tcpClient.Close();
                    return false;
                }
                
                try
                {
                    tcpClient.EndConnect(result);
                    return true;
                }
                catch
                {
                    return false;
                }
            }
        }
        catch
        {
            return false;
        }
    }

    static void StartApi()
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "dotnet",
                Arguments = "run --configuration Development",
                WorkingDirectory = ApiPath,
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            var process = Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"\n❌ Error starting API: {ex.Message}");
            Console.ResetColor();
        }
    }

    static void KillProcessByPort(int port)
    {
        try
        {
            // Method 1: Use netstat to find PID and kill it directly
            var findPidProcess = new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = $"/c netstat -ano | findstr :{port}",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };

            using (Process process = Process.Start(findPidProcess))
            {
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();

                foreach (string line in output.Split('\n'))
                {
                    var parts = line.Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length >= 5 && int.TryParse(parts[4], out int pid))
                    {
                        try
                        {
                            var p = Process.GetProcessById(pid);
                            p.Kill();
                            p.WaitForExit(2000);
                        }
                        catch { }
                    }
                }
            }
        }
        catch { }
    }

    static Process StartNgrok()
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = NgrokPath,
                Arguments = $"http {ApiPort}",
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            return Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"\n❌ Error starting ngrok: {ex.Message}");
            Console.ResetColor();
            return null;
        }
    }

    static string GetNgrokUrl()
    {
        try
        {
            using (var cts = new System.Threading.CancellationTokenSource(2000)) // 2 second total timeout
            using (var client = new HttpClient() { Timeout = TimeSpan.FromSeconds(2) })
            {
                for (int i = 0; i < 3; i++)
                {
                    try
                    {
                        var task = client.GetStringAsync("http://localhost:4040/api/tunnels");
                        if (task.Wait(1500)) // Wait max 1.5 seconds
                        {
                            var response = task.Result;
                            
                            // Parse JSON to find public URL
                            var match = Regex.Match(response, @"""public_url"":""(https?://[^""]+)""");
                            if (match.Success)
                            {
                                return match.Groups[1].Value;
                            }
                        }
                    }
                    catch { }
                    
                    if (i < 2)
                        Thread.Sleep(300);
                }
            }
        }
        catch { }

        return null;
    }

    static bool IsNgrokRunning()
    {
        try
        {
            // Check if ngrok process is running
            var ngrokProcesses = Process.GetProcessesByName("ngrok");
            return ngrokProcesses.Length > 0;
        }
        catch
        {
            return false;
        }
    }

    static void WaitForKey()
    {
        Console.WriteLine("\nPress any key to exit...");
        Console.ReadKey();
    }
}
