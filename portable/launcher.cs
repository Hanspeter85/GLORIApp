// =============================================================================
// portable/launcher.cs  -  "Start GLORIApp.exe" of the portable version
// Copyright (c) 2026 Hanspeter Wieland - PolyForm Noncommercial License 1.0.0 (see LICENSE)
// =============================================================================
// Starts the Shiny app with the R that is shipped next to this exe (folder R\),
// so no R installation is needed. The app opens in the default web browser;
// closing the browser tab stops R again.
//
// Compiled by portable/build_portable.R with the C# compiler that is part of
// every Windows installation (.NET Framework 4):
//   csc.exe /target:winexe /out:"Start GLORIApp.exe" launcher.cs
// =============================================================================
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

class GLORIAppLauncher
{
    [STAThread]
    static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string rscript = Path.Combine(dir, "R", "bin", "x64", "Rscript.exe");
        string appDir = Path.Combine(dir, "GLORIApp");
        if (!File.Exists(rscript) || !Directory.Exists(appDir))
        {
            MessageBox.Show("The folders 'R' and 'GLORIApp' must be next to this file.\n" +
                            "Please unpack the complete GLORIApp_portable folder.",
                            "GLORIApp", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        // R code: write messages to a log file, then start the app in the browser
        string log = Path.Combine(dir, "GLORIApp_log.txt").Replace("\\", "/");
        string code = "zz <- file('" + log + "', open = 'wt'); sink(zz, type = 'message'); " +
                      "shiny::runApp('app', launch.browser = TRUE)";
        var psi = new ProcessStartInfo(rscript, "-e \"" + code + "\"");
        psi.WorkingDirectory = appDir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        // use only the packages shipped in R\library, not packages of a local R installation
        psi.EnvironmentVariables["R_LIBS_USER"] = Path.Combine(dir, "R", "library-user");
        psi.EnvironmentVariables["R_LIBS"] = "";
        psi.EnvironmentVariables["GLORIAPP_PORTABLE"] = "1";
        try
        {
            Process.Start(psi);
        }
        catch (Exception e)
        {
            MessageBox.Show("GLORIApp could not be started:\n" + e.Message, "GLORIApp",
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
