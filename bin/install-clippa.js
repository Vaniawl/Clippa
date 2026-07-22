#!/usr/bin/env node

const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const https = require("node:https");

const appName = "Clippa";
const localZipPath = path.resolve(__dirname, "../outputs/Clippa.app.zip");
const defaultZipUrl = "https://raw.githubusercontent.com/Vaniawl/Clippa/main/outputs/Clippa.app.zip";
const zipUrl = process.env.CLIPPA_ZIP_URL || defaultZipUrl;

function usage() {
  console.log(`Install Clippa for macOS.

Usage:
  npx github:Vaniawl/Clippa
  npx install-clippa

Options:
  --help       Show this help.

The installer copies Clippa.app to /Applications when possible, otherwise to ~/Applications.
`);
}

function run(command, args, options = {}) {
  execFileSync(command, args, { stdio: "inherit", ...options });
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

async function main() {
  if (process.argv.includes("--help") || process.argv.includes("-h")) {
    usage();
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

    try {
      run("/usr/bin/osascript", ["-e", `tell application id "com.ivandovhosheia.Clippa" to quit`], { stdio: "ignore" });
    } catch {
      // The app may not be running or may not be installed yet.
    }

    let installDir = "/Applications";
    let installPath = path.join(installDir, `${appName}.app`);
    try {
      copyApp(appPath, installPath);
    } catch (error) {
      installDir = path.join(os.homedir(), "Applications");
      fs.mkdirSync(installDir, { recursive: true });
      installPath = path.join(installDir, `${appName}.app`);
      copyApp(appPath, installPath);
    }

    console.log(`Installed ${appName} to ${installPath}`);
    console.log("Opening Clippa...");
    run("/usr/bin/open", [installPath]);
    console.log("If automatic paste is unavailable, grant Accessibility access in System Settings.");
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
