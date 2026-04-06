# Multi-Tool Application

A Windows desktop application featuring multiple tools including a calculator and floppy disk image creator.

## Features

### Calculator
- Standard arithmetic operations (addition, subtraction, multiplication, division)
- Clean GUI interface with number pad layout
- Error handling for invalid expressions

### Floppy Disk Creator
Create empty floppy disk images for use in emulators:
- **5.25" Disks:**
  - DD (Double Density) - 360 KB
  - HD (High Density) - 1.2 MB
- **3.5" Disks:**
  - DD (Double Density) - 720 KB
  - HD (High Density) - 1.44 MB
  - ED (Extended Density) - 2.88 MB

## Installation on Windows

### Requirements
- Windows 10/11
- Administrator privileges (for installation to Program Files)

### Quick Install

1. Download or copy both files to a folder:
   - `multi_tool_app.py`
   - `install_windows.bat`

2. Right-click `install_windows.bat` and select **"Run as administrator"**

3. The installer will automatically:
   - Check if Python is installed (download and install if not)
   - Verify tkinter availability (included with official Python)
   - Install PyInstaller
   - Compile the application to a standalone EXE
   - Install to `C:\Program Files\MultiToolApp\`
   - Create desktop and Start Menu shortcuts
   - Clean up all temporary files

### Manual Installation (Alternative)

If you prefer to install manually:

```bash
# Ensure Python 3.x is installed with tkinter
pip install pyinstaller

# Compile to EXE
pyinstaller --onefile --windowed --name MultiToolApp multi_tool_app.py

# The executable will be in the dist/ folder
```

## Usage

After installation:
- Double-click the desktop shortcut
- Or find it in the Start Menu under "MultiToolApp"
- Use the tabs to switch between Calculator and Floppy Disk Creator

## File Structure

```
/workspace/
├── multi_tool_app.py      # Main application source code
├── install_windows.bat    # Windows installer script
└── README.md              # This file
```

## Technical Details

- **GUI Framework:** Tkinter (Python standard library)
- **Packaging:** PyInstaller
- **Python Version:** 3.11.9 (auto-installed if needed)
- **Installation Directory:** `C:\Program Files\MultiToolApp\`
- **Temp Files:** All downloaded files are stored in `%TEMP%` and automatically deleted after installation

## License

This software is provided as-is for educational and personal use.
