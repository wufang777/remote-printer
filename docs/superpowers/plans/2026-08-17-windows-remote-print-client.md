# Windows Remote Print Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Windows 10+ WPF Aurora Control remote-print client matching the macOS local workflow.

**Architecture:** A .NET 8 WPF executable uses a `MainViewModel` for printer discovery, selected local file, task list, preview, and connection settings. Windows-specific print and preview calls are isolated behind small service classes.

**Tech Stack:** .NET 8, WPF, C#, Windows.Printing, System.Printing, xUnit-ready project structure.

## Global Constraints

- Target `net8.0-windows` and Windows 10 22H2 or later.
- Primary release target is `win-x64`.
- Chinese UI, Aurora light appearance, 1440×900 default window.
- PDF, JPG, JPEG, and PNG file selection; task printer name must match Windows printer queue name.

---

### Task 1: Scaffold Windows project and models

**Files:**
- Create: `outputs/RemotePrintWindows/RemotePrintWindows.csproj`
- Create: `outputs/RemotePrintWindows/Models/PrintTask.cs`
- Create: `outputs/RemotePrintWindows/ViewModels/MainViewModel.cs`

- [ ] Create the WPF project, observable task model, and command-capable view model.
- [ ] Add unit-test-ready pure state properties for selected file and task status.

### Task 2: Add Aurora dashboard and local file workflow

**Files:**
- Create: `outputs/RemotePrintWindows/MainWindow.xaml`
- Create: `outputs/RemotePrintWindows/MainWindow.xaml.cs`
- Create: `outputs/RemotePrintWindows/Services/PrinterService.cs`

- [ ] Implement the 1440×900 Aurora dashboard.
- [ ] Read local printer queues, choose supported files, delete selected files, and create task cards.
- [ ] Expose confirmation/silent controls and preview entry point.

### Task 3: Add settings and release instructions

**Files:**
- Create: `outputs/RemotePrintWindows/SettingsWindow.xaml`
- Create: `outputs/RemotePrintWindows/README.md`

- [ ] Implement editable API address, device name, activation code, and default print behavior.
- [ ] Document Windows build and publish commands and Windows-only printer validation.
