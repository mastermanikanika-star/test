@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: MultiTool Suite Self-Contained Installer
:: ============================================================================
:: This script embeds the Python source code, installs Python if needed,
:: compiles the app to an EXE, and installs it to Program Files.
:: Users only need to download this single .bat file.
:: ============================================================================

:: Configuration
set "APP_NAME=MultiToolSuite"
set "INSTALL_DIR=C:\Program Files\%APP_NAME%"
set "PYTHON_VERSION=3.11.9"
set "PYTHON_INSTALLER_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-amd64.exe"
set "TEMP_DIR=%TEMP%\%APP_NAME%_Installer"
set "SOURCE_FILE=%TEMP_DIR%\app_source.py"
set "DIST_EXE=%TEMP_DIR%\dist\%APP_NAME%.exe"

:: Create Temp Directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
cd /d "%TEMP_DIR%"

:: Run as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ==========================================
echo  %APP_NAME% Installation Started
echo ==========================================

:: -----------------------------------------------------------------------------
:: Step 1: Check and Install Python
:: -----------------------------------------------------------------------------
echo [1/5] Checking for Python installation...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo Python not found. Downloading Python %PYTHON_VERSION%...
    curl -L -o python_installer.exe "%PYTHON_INSTALLER_URL%"
    
    echo Installing Python silently...
    start /wait python_installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    
    :: Refresh environment variables for current session
    set "PATH=C:\Program Files\Python311;C:\Program Files\Python311\Scripts;%PATH%"
    
    :: Verify installation
    python --version >nul 2>&1
    if %errorLevel% neq 0 (
        echo ERROR: Python installation failed.
        pause
        goto Cleanup
    )
    echo Python installed successfully.
) else (
    echo Python is already installed.
)

:: -----------------------------------------------------------------------------
:: Step 2: Install PyInstaller
:: -----------------------------------------------------------------------------
echo [2/5] Ensuring PyInstaller is installed...
pip install pyinstaller --quiet
if %errorLevel% neq 0 (
    echo WARNING: pip install had issues, trying to proceed anyway...
)

:: -----------------------------------------------------------------------------
:: Step 3: Extract Embedded Source Code
:: -----------------------------------------------------------------------------
echo [3/5] Extracting application source code...

:: Use PowerShell to robustly extract the embedded Python code
powershell -Command "$content = Get-Content '%~f0' -Raw; $startMarker = '__PYTHON_SOURCE_START__'; $endMarker = '__PYTHON_SOURCE_END__'; $startIndex = $content.IndexOf($startMarker); $endIndex = $content.IndexOf($endMarker); if ($startIndex -ge 0 -and $endIndex -gt $startIndex) { $codeStart = $startIndex + $startMarker.Length; $codeLength = $endIndex - $codeStart; $code = $content.Substring($codeStart, $codeLength); Set-Content -Path '%SOURCE_FILE%' -Value $code -Encoding UTF8; Write-Host 'Source code extracted successfully.' } else { Write-Error 'Could not find source code markers in batch file.'; exit 1 }"

if not exist "%SOURCE_FILE%" (
    echo ERROR: Failed to extract source code.
    pause
    goto Cleanup
)

:: -----------------------------------------------------------------------------
:: Step 4: Compile to EXE
:: -----------------------------------------------------------------------------
echo [4/5] Compiling application to executable...
pyinstaller --onefile --windowed --name "%APP_NAME%" --distpath "%TEMP_DIR%\dist" --workpath "%TEMP_DIR%\build" --specpath "%TEMP_DIR%" "%SOURCE_FILE%"

if not exist "%DIST_EXE%" (
    echo ERROR: Compilation failed. Check logs above.
    pause
    goto Cleanup
)
echo Compilation successful.

:: -----------------------------------------------------------------------------
:: Step 5: Install to Program Files & Create Shortcuts
:: -----------------------------------------------------------------------------
echo [5/5] Installing to %INSTALL_DIR%...

:: Create Install Directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copy EXE
copy /Y "%DIST_EXE%" "%INSTALL_DIR%\%APP_NAME%.exe"

:: Create Start Menu Shortcut
set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if not exist "%START_MENU_DIR%\%APP_NAME%" mkdir "%START_MENU_DIR%\%APP_NAME%"

powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU_DIR%\%APP_NAME%\%APP_NAME%.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\%APP_NAME%.exe'; $Shortcut.Save()"

:: Create Desktop Shortcut
set "DESKTOP_DIR=%USERPROFILE%\Desktop"
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP_DIR%\%APP_NAME%.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\%APP_NAME%.exe'; $Shortcut.Save()"

echo ==========================================
echo  Installation Complete!
echo  Location: %INSTALL_DIR%
echo ==========================================

goto Cleanup

:Cleanup
echo Cleaning up temporary files...
timeout /t 2 /nobreak >nul
rd /s /q "%TEMP_DIR%" >nul 2>&1
del /q "%TEMP%\python_installer.exe" >nul 2>&1
echo Done.
pause
exit /b 0

:: ============================================================================
:: EMBEDDED PYTHON SOURCE CODE STARTS BELOW
:: ============================================================================
__PYTHON_SOURCE_START__
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import os

class MultiToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("MultiTool Suite")
        self.root.geometry("500x400")
        self.root.resizable(False, False)

        # Style configuration
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TButton", padding=6, relief="flat", background="#ccc")
        style.configure("TLabel", font=("Arial", 10))
        style.configure("Header.TLabel", font=("Arial", 14, "bold"))

        # Notebook (Tabs)
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill='both', expand=True, padx=10, pady=10)

        # Tab 1: Calculator
        self.calc_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.calc_frame, text='Calculator')
        self.setup_calculator(self.calc_frame)

        # Tab 2: Floppy Disk Creator
        self.floppy_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.floppy_frame, text='Floppy Disk Creator')
        self.setup_floppy_creator(self.floppy_frame)

    def setup_calculator(self, parent):
        # Display
        self.display_var = tk.StringVar()
        display_entry = ttk.Entry(parent, textvariable=self.display_var, font=("Arial", 20), justify='right')
        display_entry.grid(row=0, column=0, columnspan=4, sticky='nsew', padx=5, pady=10)
        
        # Buttons layout
        buttons = [
            ('7', 1, 0), ('8', 1, 1), ('9', 1, 2), ('/', 1, 3),
            ('4', 2, 0), ('5', 2, 1), ('6', 2, 2), ('*', 2, 3),
            ('1', 3, 0), ('2', 3, 1), ('3', 3, 2), ('-', 3, 3),
            ('C', 4, 0), ('0', 4, 1), ('=', 4, 2), ('+', 4, 3),
        ]

        for (text, row, col) in buttons:
            action = lambda x=text: self.on_calc_click(x)
            btn = ttk.Button(parent, text=text, command=action)
            btn.grid(row=row, column=col, sticky='nsew', padx=2, pady=2)
            parent.grid_rowconfigure(row, weight=1)
            parent.grid_columnconfigure(col, weight=1)

    def on_calc_click(self, char):
        current = self.display_var.get()
        if char == 'C':
            self.display_var.set("")
        elif char == '=':
            try:
                # Basic safety check
                if any(op in current for op in ['+', '-', '*', '/']):
                    result = eval(current)
                    self.display_var.set(str(result))
                else:
                    self.display_var.set("")
            except Exception:
                self.display_var.set("Error")
        else:
            self.display_var.set(current + char)

    def setup_floppy_creator(self, parent):
        # Header
        header = ttk.Label(parent, text="Create Empty Floppy Image", style="Header.TLabel")
        header.pack(pady=15)

        # Selection Frame
        sel_frame = ttk.Frame(parent)
        sel_frame.pack(pady=10)

        ttk.Label(sel_frame, text="Disk Type:").grid(row=0, column=0, padx=5, sticky='e')
        
        self.disk_options = {
            "5.25\" DD (360 KB)": 360 * 1024,
            "5.25\" HD (1.2 MB)": 1200 * 1024,
            "3.5\" DD (720 KB)": 720 * 1024,
            "3.5\" HD (1.44 MB)": 1440 * 1024,
            "3.5\" ED (2.88 MB)": 2880 * 1024
        }
        
        self.disk_type_var = tk.StringVar(value="3.5\" HD (1.44 MB)")
        combo = ttk.Combobox(sel_frame, textvariable=self.disk_type_var, values=list(self.disk_options.keys()), state="readonly", width=30)
        combo.grid(row=0, column=1, padx=5)

        # Filename
        file_frame = ttk.Frame(parent)
        file_frame.pack(pady=5)
        
        ttk.Label(file_frame, text="Filename:").pack(side=tk.LEFT, padx=5)
        self.filename_var = tk.StringVar(value="disk_image.img")
        entry = ttk.Entry(file_frame, textvariable=self.filename_var, width=30)
        entry.pack(side=tk.LEFT, padx=5)

        # Create Button
        create_btn = ttk.Button(parent, text="Create Image", command=self.create_floppy_image)
        create_btn.pack(pady=20)

        # Status Label
        self.status_var = tk.StringVar()
        status_lbl = ttk.Label(parent, textvariable=self.status_var, foreground="green")
        status_lbl.pack(pady=5)

    def create_floppy_image(self):
        disk_name = self.disk_type_var.get()
        size_bytes = self.disk_options[disk_name]
        filename = self.filename_var.get()
        
        if not filename.endswith(".img"):
            filename += ".img"
            
        try:
            filepath = filedialog.asksaveasfilename(
                defaultextension=".img",
                filetypes=[("Image files", "*.img"), ("All files", "*.*")],
                initialfile=filename
            )
            
            if not filepath:
                return

            self.status_var.set("Creating image... please wait.")
            self.root.update()

            # Write zero-filled file
            # Writing in chunks to avoid memory issues
            chunk_size = 1024 * 1024  # 1MB chunks
            with open(filepath, 'wb') as f:
                remaining = size_bytes
                while remaining > 0:
                    write_size = min(chunk_size, remaining)
                    f.write(b'\x00' * write_size)
                    remaining -= write_size

            self.status_var.set(f"Success! Created {disk_name} at {os.path.basename(filepath)}")
            messagebox.showinfo("Success", f"Created {disk_name}\nSize: {size_bytes / 1024:.0f} KB\nLocation: {filepath}")
            
        except Exception as e:
            self.status_var.set("Error creating image.")
            messagebox.showerror("Error", str(e))

if __name__ == "__main__":
    root = tk.Tk()
    app = MultiToolApp(root)
    root.mainloop()
__PYTHON_SOURCE_END__
