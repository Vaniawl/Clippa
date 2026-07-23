#!/usr/bin/env node

const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const https = require("node:https");

const appName = "Clippa";
const bundleIdentifier = "com.ivandovhosheia.Clippa";
const localZipPath = path.resolve(__dirname, "../outputs/Clippa.app.zip");
const packageJson = require("../package.json");
const defaultZipUrl = "https://github.com/Vaniawl/Clippa/releases/download/v1.0.8/Clippa.app.zip";
const zipUrl = process.env.CLIPPA_ZIP_URL || defaultZipUrl;

function usage() {
  console.log(`Install Clippa for macOS.

Usage:
  npx clippa
  npm install -g clippa && clippa
  npx github:Vaniawl/Clippa

Options:
  --install-dir <path>  Copy Clippa.app into a custom applications folder.
  --no-open             Install without opening Clippa afterwards.
  --version             Show installer version.
  --help                Show this help.

The installer copies Clippa.app to /Applications when possible, otherwise to ~/Applications.
Press Command-Shift-V in a text field to open Clippa.
`);
}

function run(command, args, options = {}) {
  execFileSync(command, args, { stdio: "inherit", ...options });
}

function parseArgs(argv) {
  const options = {
    help: false,
    version: false,
    noOpen: false,
    installDir: null
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--help":
      case "-h":
        options.help = true;
        break;
      case "--version":
      case "-v":
        options.version = true;
        break;
      case "--no-open":
        options.noOpen = true;
        break;
      case "--install-dir":
        index += 1;
        if (!argv[index]) {
          throw new Error("--install-dir requires a path.");
        }
        options.installDir = expandHome(argv[index]);
        break;
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function expandHome(value) {
  if (value === "~") {
    return os.homedir();
  }
  if (value.startsWith("~/")) {
    return path.join(os.homedir(), value.slice(2));
  }
  return path.resolve(value);
}

function download(url, destination) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, response => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode)) {
        response.resume();
        download(response.headers.location, destination).then(resolve, reject);
        return;
      }

      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Download failed with HTTP ${response.statusCode}`));
        return;
      }

      const file = fs.createWriteStream(destination);
      response.pipe(file);
      file.on("finish", () => file.close(resolve));
      file.on("error", reject);
    });

    request.on("error", reject);
  });
}

function copyApp(source, destination) {
  if (fs.existsSync(destination)) {
    fs.rmSync(destination, { recursive: true, force: true });
  }
  run("/usr/bin/ditto", [source, destination]);
}

function quitRunningApp() {
  try {
    run("/usr/bin/osascript", ["-e", `tell application id "${bundleIdentifier}" to quit`], {
      stdio: "ignore",
      timeout: 3000
    });
  } catch {
    try {
      run("/usr/bin/killall", [appName], { stdio: "ignore", timeout: 3000 });
    } catch {
      // The app may not be running yet.
    }
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    usage();
    return;
  }
  if (options.version) {
    console.log(packageJson.version);
    return;
  }

  if (process.platform !== "darwin") {
    console.error("Clippa is a macOS app. Run this installer on macOS.");
    process.exit(1);
  }

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "clippa-install-"));
  const zipPath = path.join(tempDir, "Clippa.app.zip");
  const extractDir = path.join(tempDir, "extract");

  try {
    fs.mkdirSync(extractDir, { recursive: true });

    if (fs.existsSync(localZipPath)) {
      fs.copyFileSync(localZipPath, zipPath);
    } else {
      console.log(`Downloading Clippa from ${zipUrl}`);
      await download(zipUrl, zipPath);
    }

    run("/usr/bin/ditto", ["-x", "-k", zipPath, extractDir]);

    const appPath = path.join(extractDir, `${appName}.app`);
    if (!fs.existsSync(appPath)) {
      throw new Error(`Archive did not contain ${appName}.app`);
    }

    quitRunningApp();

    let installDir = options.installDir || "/Applications";
    let installPath = path.join(installDir, `${appName}.app`);
    if (options.installDir) {
      fs.mkdirSync(installDir, { recursive: true });
      copyApp(appPath, installPath);
    } else {
      try {
        copyApp(appPath, installPath);
      } catch (error) {
        installDir = path.join(os.homedir(), "Applications");
        fs.mkdirSync(installDir, { recursive: true });
        installPath = path.join(installDir, `${appName}.app`);
        copyApp(appPath, installPath);
      }
    }

    console.log(`Installed ${appName} to ${installPath}`);
    if (!options.noOpen) {
      console.log("Opening Clippa...");
      run("/usr/bin/open", [installPath]);
      console.log("Press Command-Shift-V in a text field to open Clippa. Grant Accessibility access if macOS asks.");
    }
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
