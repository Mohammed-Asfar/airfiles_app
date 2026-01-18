# Windows Installer

This folder contains the Inno Setup script for creating the Windows installer.

## Prerequisites

1. Install [Inno Setup](https://jrsoftware.org/isinfo.php)
2. Build the Windows app first:
   ```bash
   flutter build windows --release
   ```

## Creating the Installer

1. Open `airfiles_setup.iss` in Inno Setup Compiler
2. Click "Compile" (or press Ctrl+F9)
3. The installer will be created in the `output` folder

## Note

Before compiling, ensure you have created an `.ico` file from `assets/logo3.png` and placed it at `assets/logo3.ico`.

You can convert PNG to ICO using online tools like:
- https://convertio.co/png-ico/
- https://icoconvert.com/
