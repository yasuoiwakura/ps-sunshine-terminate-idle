# ps-sunshine-terminate-idle

A small PowerShell GUI tool to monitor and automatically terminate `sunshine.exe` after inactivity.  
It displays RAM usage, streaming status, and provides auto-kill functionality in a simple GUI.

---
## ⚡ Inactivity Note
This repository is functional, but was vibe coded as a quick & dirty experiment.
Features such as path detection, TCP port configuration, and GUI layout are not yet fully optimized.
It serves as a demo, not as a production-ready solution.

## ⚠️ Problem tackled

A continuously running Sunshine gaming streaming server can pose a **security risk**, since a Moonlight Steam Deck client is usually not secured.  
Leaving Sunshine running unnecessarily exposes your system to potential attacks.

---

## 💡 Solution provided

- Start Sunshine **only when needed** with a single click, allowing your Steam Deck to be used as a wireless controller.  
- Automatically terminate the Sunshine server after several minutes of inactivity.

---

## 🛠 How it Works

- UDP connections are stateless, so it is difficult to detect an active client reliably (e.g., by sniffing traffic like the system resource monitor does).  
- This script **monitors Sunshine’s RAM usage** and infers from it whether a client is currently connected. (see limitations)

---

## ⚙️ Features

- Start/Kill `sunshine.exe` via GUI buttons  
- Shows RAM usage and streaming status  
- Auto-kill on inactivity or RAM threshold exceeded  
- Adjustable kill timeout  
- Optional kill on GUI exit  
- GUI feedback via colors and countdown

---

## ⚠️ Limitations

- RAM usage may vary depending on screen resolution and must be **adjusted in the script**.  
- Currently a quick & dirty implementation – functional but not fully modular or optimized.
- GUI not very responsive (but just press ESC to exit the GUI AND terminate sunshine)

---

## 📦 Installation

1. Clone the repository:

git clone https://github.com/yourusername/ps-sunshine-terminate-idle.git

2. Run the script (PowerShell 5+):

.\sunshine_launcher_killer.ps1

3. Optional parameters:

.\sunshine_launcher_killer.ps1 -AutoStart -SunshinePath "C:\Path\To\sunshine"

---

## 📝 ToDo

- Convert the script fully to English
- Add RAM threshold adjustment in the GUI
- Suppress the console window without compiling with ps2exe
- Make TCP/UDP client detection more robust (optional)