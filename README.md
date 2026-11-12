<div align="center">

# 📷 Camera Shutter Checker

### Offline shutter-count metadata analyzer for Windows

[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Version](https://img.shields.io/badge/version-2.4.1-6f42c1)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red)](LICENSE_NOTICE.txt)

**Created and maintained by Emin Mirkarimov**  
*Independent project • Local processing • No ExifTool dependency*

---

### ⬇️ Download the Windows application

**[Download the latest EXE from GitHub Releases](https://github.com/YOUR_GITHUB_USERNAME/CameraShutterChecker/releases/latest)**

<sub>Replace `YOUR_GITHUB_USERNAME` with the GitHub account that owns this repository after creating it.</sub>

[Русская версия документации](README_RU.md) · [How to publish this project](GITHUB_SETUP_RU.md) · [Changelog](CHANGELOG.md)

</div>

---

## ✨ What is Camera Shutter Checker?

Camera Shutter Checker is a Windows utility that examines image and RAW-file metadata and looks for shutter-actuation or image-counter fields written by a camera manufacturer.

The application uses its own embedded EXIF/TIFF/MakerNotes parsing code. **ExifTool is not required.** During normal analysis, files are processed locally on the user's computer and are not uploaded to a server.

The goal is simple: show a value only when the parser finds a recognized field. If a camera does not store a lifetime shutter count in the photo, the application reports that the value was not found instead of guessing from the filename or folder sequence.

> [!IMPORTANT]
> There is no universal shutter-count field for every camera. Support depends on the exact camera model, firmware, file format and metadata retained in the original file. A file being selectable by the application does not mean that its shutter count is supported.

## 🧭 Camera support matrix

The table below describes the current code paths, not a guarantee that every model has been physically tested. **Practical testing has so far been carried out on a Sony camera.** Other manufacturers are at different implementation and validation stages.

| Manufacturer | Formats / metadata path | Current status | Important notes |
|---|---|---|---|
| **Sony** | ARW, SR2, JPEG/TIFF MakerNotes; tags `0x9050`, legacy fields | 🟢 **Practically tested on a Sony camera** | Model-specific decoding paths are implemented for selected Alpha/FX bodies. The exact model and original file matter. |
| **Canon** | CR2 MakerNotes / `FileInfo`; CR3 `CMT` / `CTMD` / `CameraInfo` | 🟡 **Partial support** | Only selected EOS models and metadata layouts are handled. Many Canon cameras do not put a lifetime shutter count in the image file. |
| **Nikon** | MakerNotes fields `0x00A7` and `0x0037` | 🟡 Implemented; hardware validation pending | A counter is shown only when one of the recognized fields is present and readable. |
| **Fujifilm** | MakerNotes field `0x1438` (`ImageCount`) | 🟡 Implemented; hardware validation pending | `ImageCount` may not be the lifetime mechanical shutter count and can be reset or behave differently by model. |
| **Pentax / Ricoh** | Manufacturer MakerNotes counter layout | 🟡 Implemented; hardware validation pending | The current decoder handles a particular known layout; it is not a promise of support for every body. |
| **Samsung** | Pentax-style MakerNotes decoding path | 🧪 Experimental / unverified | Requires real-device samples before describing it as validated support. |
| **Panasonic / Lumix** | — | ⚪ Not implemented as a verified counter decoder | Camera identification or generic EXIF reading does not mean shutter-count extraction is available. |
| **OM System / Olympus** | — | ⚪ Not implemented as a verified counter decoder | Model-specific support is not yet validated. |
| **Leica and other brands** | — | ⚪ Not implemented as a verified counter decoder | May be considered for future versions. |

### Sony: current model-specific decoding paths

The code includes several Sony MakerNote layouts. The following model identifiers are included in the current model-selection logic; this list is **not** a claim that every listed camera has been individually tested on hardware.

<details>
<summary><strong>Sony 0x9050 / offset 0x3A family</strong></summary>

`ILCE-7M3`, `ILCE-7RM2`, `ILCE-7RM3`, `ILCE-7RM4`, `ILCE-7SM2`, `ILCE-6100`, `ILCE-6300`, `ILCE-6400`, `ILCE-6500`, `ILCE-6600`, `ILCE-7C`, `ILCE-9`, `ILCE-9M2`, `ILCA-99M2`, `ILCE-1`, `ILCE-7M4`, `ILCE-7RM5`, `ILCE-7SM3`, `ILME-FX3`.

</details>

<details>
<summary><strong>Sony 0x9050d / offset 0x0A family</strong></summary>

`ILCE-6700`, `ILCE-7CM2`, `ILCE-7CR`, `ZV-E1`, `ILCE-1M2`, `ILCE-7M5`, `ILCE-7RM6`.

</details>

<details>
<summary><strong>Early Sony 0x9050a / offset 0x32 family</strong></summary>

`ILCE-7`, `ILCE-7R`, `ILCE-7S`, `ILCE-7M2`.

</details>

The Sony parser also contains a legacy MakerNote path for selected older Alpha bodies. Sony metadata layouts can differ between generations; an unsupported body may be identified correctly while its counter remains unavailable.

### Canon: deliberately partial support

Canon is **not presented as universally supported**. The current code contains separate CR2 and CR3 parsing paths, but only selected model layouts are recognized.

**Canon CR3 — model-specific CameraInfo offsets currently implemented:**

| Model family | Current code path | Status / caveat |
|---|---|---|
| EOS R5 / EOS R5 C / EOS R6 | CameraInfo offset `0x0AF1` | Model-specific decoding path; not a guarantee for all firmware/file variants. |
| EOS R6 Mark II / EOS R8 / EOS R50 | CameraInfo offset `0x0D29` | Model-specific decoding path; requires original CR3 metadata. |
| Original EOS R / EOS RP | Candidate offsets `0x0194` / `0x0960` | **Experimental**; the result should be cross-checked with the same camera's known counter. |
| EOS R6 Mark III | `ImageCount` only | Explicitly **not** reported as a lifetime shutter count; it may reset when the card is formatted. |

**Canon CR2 — selected legacy professional bodies:**

The current parser attempts to read `FileInfo` for selected EOS-1D / EOS-1Ds Mark II-era bodies, including Mark II / Mark II N variants. It intentionally avoids reporting questionable values for some Mark III layouts. Most consumer EOS DSLR families (for example, many 5D, 6D, 7D, xxD and Rebel bodies) do not expose a reliable lifetime shutter count in the image metadata, so a photo alone may not be enough.

> [!WARNING]
> A Canon camera being recognized as Canon, or a CR2/CR3 file being successfully opened, does not mean its lifetime shutter count is readable. Some models require a USB/PTP connection, a service utility or an authorized service center.

### How to interpret the result

- **Counter found** — a recognized field was read. Check the label: `ShutterCount`, `MechanicalShutterCount` and `ImageCount` are not automatically interchangeable.
- **Not found** — no supported counter was found in that file. This does not mean the camera has zero actuations.
- **Unsupported layout / model** — the camera or metadata layout is outside the current decoder coverage.
- **Experimental candidate** — the value is a model-specific candidate and should be validated against a known counter from that exact camera.

The shutter-count concept itself varies: mechanical shutter actuations, electronic shutter frames, total exposures and image sequence counters may be different quantities.

## 🚀 Download and run

1. Open the repository's **Releases** page.
2. Open the latest release.
3. Under **Assets**, download `CameraShutterChecker.exe`.
4. Run the downloaded file on Windows 10/11 x64.
5. Select one or more original photo/RAW files, or drag files onto the application launcher.

**Direct download URL template:**

```text
https://github.com/YOUR_GITHUB_USERNAME/CameraShutterChecker/releases/latest/download/CameraShutterChecker.exe
```

Replace `YOUR_GITHUB_USERNAME` with the repository owner's GitHub username.

> [!NOTE]
> The release EXE will be available after the maintainer builds and publishes it. The source repository and the downloadable binary are separate: source code belongs in the repository; the compiled EXE belongs in a GitHub Release asset.

## 🖥️ Run from source

Requirements:

- Windows 10 or Windows 11, 64-bit.
- Windows PowerShell 5.1 (included with supported Windows versions) for the supplied source launcher.
- No ExifTool, Python or external metadata utility is needed by the application.
- No internet connection is needed for ordinary file analysis.

Steps:

1. Download the repository using **Code → Download ZIP**, or clone it.
2. Extract the archive.
3. Keep `CameraShutterCheck.ps1` and `CameraShutterCheck.bat` in the same directory.
4. Run `CameraShutterCheck.bat`.
5. Select original files in the dialog, or drag them onto the BAT file.

## 🛠️ Build the EXE yourself

The repository includes a build helper:

```text
BUILD_EXE.bat
Build-EXE.ps1
```

On Windows, double-click `BUILD_EXE.bat`. On the first build, the script installs the **PS2EXE** module from the PowerShell Gallery for compilation. It creates:

```text
dist/
└── CameraShutterChecker.exe
```

PS2EXE is a build-time dependency only. It is not required to run the source script, and users who download the published EXE do not need to install PS2EXE separately. The resulting EXE is a packaged PowerShell application, not a native reimplementation of the parser; it still relies on Windows PowerShell/.NET components available on the target Windows system. The console is intentionally enabled because the current application prints its report there.

## 📦 Automatic GitHub Release build

The repository includes a GitHub Actions workflow at `.github/workflows/release.yml`.

When the maintainer pushes a version tag such as `v2.4.1`, GitHub Actions:

1. checks out the source code;
2. installs PS2EXE on a temporary Windows runner;
3. builds `CameraShutterChecker.exe`;
4. creates a GitHub Release for that tag;
5. attaches the EXE to the Release so visitors can download it from **Releases → Assets**.

Example commands from the project folder after configuring the `origin` remote:

```bash
git add .
git commit -m "Prepare Camera Shutter Checker v2.4.1"
git push origin main

git tag v2.4.1
git push origin v2.4.1
```

Then open the repository's **Actions** tab to monitor the build and **Releases** to confirm that the EXE is attached. See [GITHUB_SETUP_RU.md](GITHUB_SETUP_RU.md) for the full walkthrough.

## 🔒 Privacy and file handling

- Photos are processed locally by the application.
- The application does not upload photographs to a remote server.
- Use original files copied directly from the camera memory card whenever possible.
- Lightroom, Photoshop, messaging apps and social networks may remove or rewrite MakerNotes during export.
- Do not upload private RAW samples to a public issue. Ask the maintainer before sharing a sample privately.

## 📁 Repository contents

```text
CameraShutterChecker/
│
├── CameraShutterCheck.ps1       # Main application and embedded metadata parser
├── CameraShutterCheck.bat       # Launch from source / drag-and-drop entry point
├── BUILD_EXE.bat                # One-click Windows EXE build
├── Build-EXE.ps1                # PS2EXE build configuration and version metadata
│
├── README.md                    # Main English project page shown by GitHub
├── README_RU.md                 # Full Russian documentation
├── GITHUB_SETUP_RU.md           # Step-by-step repository and Release guide
├── CHANGELOG.md                 # Version history
├── RELEASE_NOTES_TEMPLATE.md    # Template for publishing a release
├── LICENSE_NOTICE.txt           # Copyright and usage notice
├── .gitignore                   # Excludes generated files and private samples
│
└── .github/
    ├── ISSUE_TEMPLATE/
    │   └── bug_report.md        # Camera compatibility / bug report template
    └── workflows/
        └── release.yml          # Build and publish EXE on version tags
```

## 🐞 Report a bug / request a camera model

Open **Issues → New issue** and include:

```text
Application version:
Camera manufacturer:
Exact camera model:
File extension: ARW / CR2 / CR3 / NEF / RAF / JPG / other
Original file from memory card? Yes / No
Result shown by the application:
Expected counter source (if known):
```

Please do not attach personal photographs or identifiable people. A short error message and camera model are usually a better first step. If a sample file is necessary, remove private content where possible and share it only through a private channel agreed with the maintainer.

## 🗺️ Roadmap

- [ ] Expand camera-specific Sony test coverage across more bodies and firmware versions.
- [ ] Validate Canon CR2/CR3 offsets using real files from the exact camera models.
- [ ] Add additional Nikon, Fujifilm, Pentax and Ricoh test samples.
- [ ] Add verified Panasonic, OM System/Olympus and Leica decoder modules where metadata permits.
- [ ] Improve the graphical interface and create clearer per-field confidence labels.
- [ ] Investigate USB/PTP reading for cameras that do not store lifetime count in image files.

## 👤 Author and rights

**Created and maintained by:** Emin Mirkarimov  
**Copyright:** Copyright (c) 2026 Emin Mirkarimov. All rights reserved.

This repository is public for project visibility and distribution of the published application. **No open-source license is granted at this time.** Do not assume that public visibility grants permission to copy, modify, redistribute or create derivative works. See [`LICENSE_NOTICE.txt`](LICENSE_NOTICE.txt).

---

<div align="center">

**Camera Shutter Checker** · Built with care for photographers  
*Created by Emin Mirkarimov*

</div>
