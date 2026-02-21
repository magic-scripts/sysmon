# sysmon

System monitoring tool with visual bar charts. Displays CPU, RAM, SWAP, and DISK usage with auto-colored progress bars.

## Features

- 📊 **Visual bar charts** - Beautiful progress bars with color coding
- 🎨 **Auto color coding** - Green (0-60%), Yellow (60-80%), Red (80-100%)
- 🔄 **Real-time updates** - Watch mode enabled by default
- 🎯 **Focus modes** - CPU, RAM, or Disk-specific views
- 📈 **Top processes** - Show resource-hungry processes
- ⌨️ **Interactive sorting** - Switch between CPU/Memory with c/m keys
- 🌍 **Cross-platform** - Works on macOS and Linux

## Installation

Requires [Magic Scripts](https://github.com/magic-scripts/ms):

```sh
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
ms install sysmon
```

## Usage

### Basic

```sh
# Show all metrics (default)
sysmon

# Focus on CPU
sysmon --cpu

# Focus on memory
sysmon --ram

# Focus on disk
sysmon --disk
```

### Top Processes

```sh
# Show top 5 CPU processes
sysmon --cpu --top 5

# Show top 10 memory processes
sysmon --ram --top 10

# Interactive mode - press 'c' for CPU, 'm' for Memory
sysmon --top 5
```

### Advanced

```sh
# Update every 2 seconds (default: 1s)
sysmon --interval 2

# Combine options
sysmon --cpu --top 5 --interval 2
```

## Output Example

```
════════════════════════════════════════════════════════════
           System Monitor v0.1.0
           Darwin 25.2.0 | 2026-02-21 15:30:45
════════════════════════════════════════════════════════════

CPU:          45% [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░]
Memory:       68% [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░]
SWAP:         12% [▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]
Disk (/):     85% [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░]

Update: 1s | Ctrl+C to exit
```

## Color Codes

- 🟢 **Green** (0-60%) - Normal usage
- 🟡 **Yellow** (60-80%) - High usage
- 🔴 **Red** (80-100%) - Critical usage

## Platform Support

- ✅ macOS (Darwin)
- ✅ Linux (Ubuntu, Debian, RHEL, etc.)
- ✅ POSIX shell compliant

## License

MIT
