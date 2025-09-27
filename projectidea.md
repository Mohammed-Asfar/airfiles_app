# 🌬️ AirFiles

**AirFiles** is a lightweight mobile application that turns your phone into a **local file-sharing server**, allowing anyone on the same Wi-Fi network to access and download your files instantly via a simple web browser—no app installation required.

---

## 🚀 App Concept
AirFiles makes file sharing **as easy as opening a browser**.  
Start the app → select files/folders → share the generated local URL (e.g. `http://192.168.x.x:8080`) → anyone on the same Wi-Fi can view and download.

---

## ✨ Key Features

### 📂 Core
- **Local HTTP Server**  
  Your phone hosts a temporary HTTP server to share files directly.
- **Folder & File Sharing**  
  Share single files or entire folders with automatic directory listing.
- **Zero Setup**  
  No account, no cloud, no internet—just a local network.

### 🔗 Access
- **Instant URL Generation**  
  Displays a local URL (e.g. `http://192.168.1.25:8080`) for connected devices.
- **QR Code Sharing**  
  Quickly share the access link by scanning a QR code.

### ⚡ Performance
- **High-Speed Transfers**  
  Uses local Wi-Fi for maximum speed, not limited by internet bandwidth.
- **Multi-Device Access**  
  Multiple devices can download files simultaneously.

### 🔒 Security
- **Optional Password Protection**  
  Lock access with a simple password if desired.
- **Read-Only Sharing**  
  Clients can only download, never modify your files.

### 📱 User Experience
- **Clean & Minimal UI**  
  Simple start/stop server button with status indicators.
- **File Preview**  
  Supports preview for common file types (images, text, PDFs).
- **Dark Mode**  
  Modern interface with light and dark themes.

---

## 🛠️ Tech Stack
- **Frontend/App:** Flutter (cross-platform: Android & iOS)
- **Backend:** Dart `HttpServer` or `shelf` for HTTP serving
- **Extras:** `mime` package for content-type detection, `qr_flutter` for QR code generation

---

## 🌟 Future Enhancements
- 🔄 **Drag & Drop Uploads** (allow users to upload back to the phone)
- 🌍 **Bluetooth / Hotspot Support** (for sharing without Wi-Fi)
- ⚡ **Background Server Mode** (keep sharing even when the app is minimized)
- 🔑 **Encryption** for secure transfers

---

## 🎯 Target Users
- Students sharing project files in classrooms
- Office teams exchanging documents quickly
- Anyone needing instant, private, and high-speed local file sharing

---

## 🏁 Vision
AirFiles aims to provide the **fastest**, **simplest**, and **most private** way to share files between devices without relying on cloud services.
