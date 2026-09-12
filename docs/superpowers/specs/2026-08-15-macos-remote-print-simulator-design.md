# macOS Remote Print Simulator — Design

## Goal

Create a macOS 14+ native Swift menu-bar simulator for a remote-print client. It validates the platform-to-device workflow before integration with the real platform or a real printer.

## Scope

- A menu-bar app that shows connection and recent-job status.
- A local simulator panel that creates PDF, image, label, and receipt jobs.
- Printer discovery from the local system, with a selectable target printer per job.
- A setting for confirmation-before-printing or silent printing.
- Job lifecycle reporting: received, awaiting confirmation, printing, succeeded, failed, or cancelled.
- A simulated cloud transport behind a protocol so the production HTTP/WebSocket transport can replace it later.

## Architecture

`AppState` owns configuration, printers, and the job queue. `TaskTransport` publishes incoming jobs and accepts status acknowledgements. The first implementation, `SimulatedTransport`, is local-only. `PrinterCatalog` enumerates printers through AppKit printing APIs. `PrintService` converts a job payload into a print operation. `ConfirmationService` asks for approval when required. SwiftUI supplies the settings window and simulator panel; AppKit hosts the menu-bar integration and printing APIs.

## Data Flow

1. The simulator creates a job with a content type and a target printer.
2. The transport delivers the job to the queue and records it as received.
3. The app verifies that the requested printer is available.
4. If confirmation is enabled, the user approves or cancels the job.
5. The print service executes a simulated print operation and posts the terminal status.
6. The activity view retains recent jobs and error details.

## Security and Failure Handling

The simulator uses no network listener, credentials, or real cloud data. It rejects missing printers, unsupported payloads, duplicate jobs, and jobs cancelled during confirmation. A future production transport must use outbound authenticated TLS connections and short-lived device credentials.

## Acceptance Criteria

- Runs on macOS 14 or later.
- Shows local printers and lets a simulated job select one.
- Supports PDF, image, label, and receipt job types.
- Demonstrates both confirmation and silent modes.
- Shows each job's lifecycle and failure reason without requiring a real remote service.

## Testing

Unit tests cover job state transitions, validation, duplicate detection, and confirmation decisions. A manual smoke test covers printer discovery, all four job types, approval, cancellation, silent mode, and an unavailable-printer failure.
