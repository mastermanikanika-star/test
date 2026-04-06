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
set "VERSION_FILE=%INSTALL_DIR%\version.xml"
set "CURRENT_VERSION=1.0.1"

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
:: Step 0: Check for Existing Installation and Version
:: -----------------------------------------------------------------------------
set "DO_UPDATE=false"
if exist "%VERSION_FILE%" (
    echo [0/6] Existing installation detected. Checking version...
    for /f "tokens=2 delims=<>" %%a in ('findstr /C:"<version>" "%VERSION_FILE%"') do set "INSTALLED_VERSION=%%a"
    echo Installed version: %INSTALLED_VERSION%
    echo New version: %CURRENT_VERSION%
    if "!INSTALLED_VERSION!"=="%CURRENT_VERSION%" (
        echo Versions match. Performing repair installation...
    ) else (
        echo Version mismatch. Proceeding with update...
        set "DO_UPDATE=true"
    )
) else (
    echo [0/6] No existing installation found. Proceeding with fresh install...
)

:: -----------------------------------------------------------------------------
:: Step 1: Check and Install Python
:: -----------------------------------------------------------------------------
echo [1/6] Checking for Python installation...
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
echo [2/6] Ensuring PyInstaller is installed...
pip install pyinstaller --quiet
if %errorLevel% neq 0 (
    echo WARNING: pip install had issues, trying to proceed anyway...
)

:: -----------------------------------------------------------------------------
:: Step 3: Extract Embedded Source Code
:: -----------------------------------------------------------------------------
echo [3/6] Extracting application source code...

:: Use PowerShell to extract the embedded Python code using a temporary script
set "PS_SCRIPT=%TEMP_DIR%\extract.ps1"
(
echo $batFile = '%~f0'
echo $sourceFile = '%SOURCE_FILE%'
echo $content = Get-Content $batFile -Raw -Encoding UTF8
echo $startMarker = '__PYTHON_SOURCE_START__'
echo $endMarker = '__PYTHON_SOURCE_END__'
echo $startIndex = $content.IndexOf($startMarker)
echo $endIndex = $content.IndexOf($endMarker)
echo if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
echo     $codeStart = $startIndex + $startMarker.Length
echo     $codeLength = $endIndex - $codeStart
echo     $code = $content.Substring($codeStart, $codeLength)
echo     Set-Content -Path $sourceFile -Value $code -Encoding UTF8 -NoNewline
echo     Write-Host 'Source code extracted successfully.'
echo } else {
echo     Write-Error 'Could not find source code markers in batch file.'
echo     exit 1
echo }
) > "%PS_SCRIPT%"

powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

if not exist "%SOURCE_FILE%" (
    echo ERROR: Failed to extract source code.
    pause
    goto Cleanup
)

:: -----------------------------------------------------------------------------
:: Step 4: Compile to EXE
:: -----------------------------------------------------------------------------
echo [4/6] Compiling application to executable...
echo Running PyInstaller...
pyinstaller --onefile --windowed --name "%APP_NAME%" --distpath "%TEMP_DIR%\dist" --workpath "%TEMP_DIR%\build" --specpath "%TEMP_DIR%" "%SOURCE_FILE%" 2>&1

if not exist "%DIST_EXE%" (
    echo ERROR: Compilation failed. Check logs above.
    echo Checking build log files...
    if exist "%TEMP_DIR%\build\%APP_NAME%\warn-%APP_NAME%.txt" (
        type "%TEMP_DIR%\build\%APP_NAME%\warn-%APP_NAME%.txt"
    )
    pause
    goto Cleanup
)
echo Compilation successful.
echo EXE location: %DIST_EXE%
for %%I in ("%DIST_EXE%") do echo EXE size: %%~zI bytes

:: -----------------------------------------------------------------------------
:: Step 5: Install to Program Files & Create Shortcuts
:: -----------------------------------------------------------------------------
echo [5/6] Installing to %INSTALL_DIR%...

:: Create Install Directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copy EXE
echo Copying executable...
copy /Y "%DIST_EXE%" "%INSTALL_DIR%\%APP_NAME%.exe"
if %errorLevel% neq 0 (
    echo ERROR: Failed to copy executable.
    pause
    goto Cleanup
)

:: Verify the executable was copied successfully
if not exist "%INSTALL_DIR%\%APP_NAME%.exe" (
    echo ERROR: Executable not found after copy operation.
    pause
    goto Cleanup
)

:: Verify file size matches
for %%I in ("%INSTALL_DIR%\%APP_NAME%.exe") do set "INSTALLED_SIZE=%%~zI"
echo Installed EXE size: %INSTALLED_SIZE% bytes
if "%INSTALLED_SIZE%"=="0" (
    echo ERROR: Installed executable is empty.
    pause
    goto Cleanup
)

echo Executable copied successfully.

:: Create version.xml file
echo [6/6] Creating version file...
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<application^>
echo     ^<name^>%APP_NAME%^</name^>
echo     ^<version^>%CURRENT_VERSION%^</version^>
echo     ^<install_date^>%date% %time%^</install_date^>
echo     ^<executable^>%INSTALL_DIR%\%APP_NAME%.exe^</executable^>
echo ^</application^>
) > "%VERSION_FILE%"

:: Verify the version file was created successfully
if not exist "%VERSION_FILE%" (
    echo ERROR: Failed to create version file.
    pause
    goto Cleanup
)
echo Version file created: %VERSION_FILE%

:: Create Start Menu Shortcut
echo Creating Start Menu shortcut...
set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if not exist "%START_MENU_DIR%\%APP_NAME%" mkdir "%START_MENU_DIR%\%APP_NAME%"

powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU_DIR%\%APP_NAME%\%APP_NAME%.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\%APP_NAME%.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Save()"
if %errorLevel% neq 0 (
    echo WARNING: Failed to create Start Menu shortcut.
) else (
    echo Start Menu shortcut created.
)

:: Create Desktop Shortcut
echo Creating Desktop shortcut...
set "DESKTOP_DIR=%USERPROFILE%\Desktop"
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP_DIR%\%APP_NAME%.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\%APP_NAME%.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Save()"
if %errorLevel% neq 0 (
    echo WARNING: Failed to create Desktop shortcut.
) else (
    echo Desktop shortcut created.
)

echo ==========================================
echo  Installation Complete!
echo  Location: %INSTALL_DIR%
echo  Version: %CURRENT_VERSION%
echo ==========================================

:: Launch the application
echo Launching %APP_NAME%...
timeout /t 2 /nobreak >nul

:: Verify executable exists and is valid before launching
if not exist "%INSTALL_DIR%\%APP_NAME%.exe" (
    echo ERROR: Could not find the application executable.
    echo Please check: %INSTALL_DIR%\%APP_NAME%.exe
    goto EndInstall
)

:: Check file size to ensure it's not empty or corrupted
for %%I in ("%INSTALL_DIR%\%APP_NAME%.exe") do set "EXE_SIZE=%%~zI"
if "%EXE_SIZE%"=="0" (
    echo ERROR: The executable file is empty or corrupted.
    goto EndInstall
)

echo Starting %APP_NAME% from %INSTALL_DIR%\%APP_NAME%.exe...
start "" "%INSTALL_DIR%\%APP_NAME%.exe"

:EndInstall
echo ==========================================
echo  Installation Complete!
echo  Location: %INSTALL_DIR%
echo  Version: %CURRENT_VERSION%
echo ==========================================
if "%EXE_SIZE%"=="" (
    echo WARNING: Application may not have launched correctly.
    echo Please try running it manually from the Start Menu or Desktop.
) else (
    echo Application launched successfully.
)

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
