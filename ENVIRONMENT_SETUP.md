# AI Diet Coach：Windows 完整環境安裝指南

本指南讓 Windows 電腦能開發並執行本專案：

- Flutter / Dart 行動端（Material Design 3）
- Android 實機或模擬器測試
- Python FastAPI 後端

專案位置：`D:\ai_diet_coach`

---

## 0. 先確認磁碟空間

Flutter、Android SDK、模擬器與套件快取都會占用大量空間。請至少保留：

- C 槽：10 GB 可用空間（系統與部分暫存仍可能使用 C 槽）
- D 槽：25 GB 以上可用空間（SDK、Android Emulator、專案）

在 PowerShell 檢查：

```powershell
Get-PSDrive C, D
```

本專案建議位置：

```text
D:\flutter                 Flutter SDK（已存在）
D:\Android\Sdk             Android SDK（建議安裝位置）
D:\Android\.android        Android 模擬器資料（選用）
D:\flutter-temp            Flutter 下載暫存
D:\pub-cache               Dart / Flutter 套件快取
D:\ai_diet_coach           本專案
```

---

## 1. 必備軟體

| 軟體 | 用途 | 必要性 |
|---|---|---|
| Git for Windows | Flutter SDK 更新與版本控制 | 必要 |
| Flutter SDK | Flutter 與 Dart 開發工具 | 必要 |
| Android Studio | Android SDK、模擬器與裝置工具 | Android 必要 |
| VS Code | 程式編輯器 | 建議 |
| Python 3.11+ | FastAPI 後端 | 後端必要 |

建議安裝 VS Code 擴充功能：

- Flutter
- Dart
- Python
- Pylance

官方參考：

- [Flutter Windows 安裝](https://docs.flutter.dev/install/manual)
- [Flutter Android 設定](https://docs.flutter.dev/platform-integration/android/setup)
- [Python for Windows](https://docs.python.org/3/using/windows.html)

---

## 2. 設定 Flutter SDK

本電腦 Flutter SDK 位於：`D:\flutter`。

### 2.1 將 Flutter 加入永久 PATH

1. 按 Windows 鍵，搜尋並開啟「編輯使用者帳戶的環境變數」。
2. 在「使用者變數」選取 `Path`，按「編輯」。
3. 按「新增」，加入：

```text
D:\flutter\bin
```

4. 一路按「確定」儲存。
5. **完全關閉並重新開啟** PowerShell 與 VS Code。

> Flutter 官方要求將 SDK 的 `bin` 目錄放入 PATH，否則找不到 `flutter` 指令。

### 2.2 將暫存與套件快取放到 D 槽

C 槽空間不足時，Flutter 會在下載套件時出現 `OS Error: 磁碟的空間不足 (errno = 112)`。

先建立資料夾：

```powershell
New-Item -ItemType Directory -Force D:\flutter-temp, D:\pub-cache | Out-Null
```

接著回到「使用者環境變數」，新增或修改：

| 變數名稱 | 值 |
|---|---|
| `TEMP` | `D:\flutter-temp` |
| `TMP` | `D:\flutter-temp` |
| `PUB_CACHE` | `D:\pub-cache` |

儲存後，重新開啟 PowerShell。

### 2.3 驗證 Flutter

```powershell
flutter --version
dart --version
flutter doctor -v
```

`flutter doctor -v` 會列出尚未完成的 Android、IDE、授權或裝置設定。先修正標示為 `[✗]` 的項目。

---

## 3. 安裝與設定 Android Studio / Android SDK

### 3.1 安裝 Android Studio

從 [Android Studio 官方網站](https://developer.android.com/studio) 安裝最新版 Stable。

### 3.2 安裝 Android SDK 工具

開啟 Android Studio：

- 在歡迎畫面：`More Actions → SDK Manager`
- 已開啟專案時：`Tools → SDK Manager`

將 **Android SDK Location** 改成：

```text
D:\Android\Sdk
```

在 **SDK Platforms**：

- 安裝最新穩定 Android SDK Platform（依畫面所示 API Level）

在 **SDK Tools**：

- 勾選 Android SDK Build-Tools
- 勾選 Android SDK Command-line Tools (latest)
- 勾選 Android SDK Platform-Tools
- 若要使用模擬器：勾選 Android Emulator
- 若要建置需要原生套件的功能：依需求安裝 CMake 與 NDK (Side by side)

按 `Apply → OK`，等待下載完成。

### 3.3 告訴 Flutter Android SDK 的位置

重新開啟 PowerShell：

```powershell
flutter config --android-sdk D:\Android\Sdk
flutter doctor --android-licenses
flutter doctor -v
```

執行 `flutter doctor --android-licenses` 時，對每個授權輸入 `y`。

### 3.4 可選：永久加入 adb PATH

在使用者 `Path` 新增：

```text
D:\Android\Sdk\platform-tools
```

重新開 PowerShell 後驗證：

```powershell
adb version
```

---

## 4. 使用 Android 實機

### 4.1 手機端設定

1. 設定 → 關於手機 → 連按「版本號碼」7 次，啟用開發人員選項。
2. 設定 → 開發人員選項 → 開啟「USB 偵錯」。
3. 以**可傳輸資料**的 USB 線連接電腦；手機 USB 模式選「檔案傳輸」。
4. 手機跳出「允許 USB 偵錯？」時，勾選「一律允許這部電腦」，按「允許」。

### 4.2 電腦端驗證

```powershell
adb devices
flutter devices
```

成功範例：

```text
List of devices attached
R58Nxxxxxxx    device
```

若顯示 `unauthorized`：在手機接受 RSA 授權。若沒有跳窗，在手機「開發人員選項」按「撤銷 USB 偵錯授權」，拔插 USB 後再試。

若完全沒有裝置：

- 換一條可傳輸資料的 USB 線與 USB 埠
- 重新插拔並選擇「檔案傳輸」
- 在 Windows 裝置管理員檢查是否出現未知裝置
- 安裝手機品牌對應的 Windows USB 驅動程式
- 重啟 adb：

```powershell
adb kill-server
adb start-server
adb devices
```

---

## 5. 使用 Android Emulator（選用）

1. Android Studio → `More Actions → Virtual Device Manager`。
2. `Create Device`，選擇 Pixel 類型裝置。
3. 下載並選擇一個 Android 系統映像檔。
4. 建立後，按播放按鈕啟動模擬器。
5. 回到 PowerShell：

```powershell
flutter emulators
flutter devices
flutter run
```

> 模擬器很占空間，也需要在 BIOS / Windows 啟用虛擬化功能；若電腦資源不足，優先使用實機測試。

---

## 6. 建立並執行 Flutter App

本專案已包含 `lib/` 的 UI 程式碼與 `pubspec.yaml`。第一次需由 Flutter 生成原生 Android 專案檔案。

```powershell
cd D:\ai_diet_coach\mobile
flutter create --platforms=android .
flutter pub get
flutter run
```

指定裝置時：

```powershell
flutter devices
flutter run -d <裝置ID>
```

常用指令：

```powershell
flutter analyze
flutter test
flutter clean
flutter pub get
```

### 可選：先用瀏覽器預覽 UI

沒有 Android 裝置時，可加入 Web 平台並在 Edge 測試：

```powershell
cd D:\ai_diet_coach\mobile
flutter create --platforms=android,web .
flutter run -d edge
```

---

## 7. 安裝 Python 與啟動 FastAPI 後端

### 7.1 安裝 Python

安裝 Python 3.11 或更新版本。安裝後驗證：

```powershell
python --version
py --version
```

如果只出現 Microsoft Store 的 Python 捷徑或 `python` 無法啟動：

1. 從 [Python 官方下載頁](https://www.python.org/downloads/windows/) 安裝 Python。
2. 安裝時勾選 **Add Python to PATH**。
3. 重新開啟 PowerShell 後再次確認 `python --version`。

### 7.2 建立虛擬環境並安裝後端套件

每個 Python 專案應使用獨立虛擬環境，避免套件版本互相影響。

```powershell
cd D:\ai_diet_coach\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

如果 PowerShell 阻止啟用虛擬環境，可只對目前帳號設定：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

然後重新執行啟用指令。

### 7.3 啟動與測試 API

```powershell
cd D:\ai_diet_coach\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

瀏覽器開啟：

```text
http://127.0.0.1:8000/docs
```

另開一個 PowerShell 視窗測試：

```powershell
cd D:\ai_diet_coach\backend
.\.venv\Scripts\Activate.ps1
pytest
```

FastAPI 官方建議以虛擬環境隔離專案套件。

---

## 8. 開發順序（每次開始工作）

### 前端終端機

```powershell
cd D:\ai_diet_coach\mobile
flutter pub get
flutter run
```

### 後端終端機

```powershell
cd D:\ai_diet_coach\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

不要將 AI API key 寫進 Flutter 的 Dart 程式碼、`pubspec.yaml` 或 Git。AI 服務金鑰未來只放在後端的 `.env`；可參考 `backend\.env.example`。

---

## 9. 故障排除速查

| 現象 | 原因與處理 |
|---|---|
| `flutter` 無法辨識 | 在使用者 `Path` 加入 `D:\flutter\bin`，完全重開終端機。 |
| `OS Error: 磁碟的空間不足` | 清出 C 槽，並將 `TEMP`、`TMP`、`PUB_CACHE` 指到 D 槽。 |
| `No supported devices connected` | 專案只生成 Android 平台，但沒有 Android 實機／模擬器；執行 `adb devices`。 |
| `adb` 無法辨識 | 安裝 Android SDK Platform-Tools，並加入 `D:\Android\Sdk\platform-tools` 到 PATH。 |
| `unauthorized` | 在手機接受 USB 偵錯 RSA 授權；必要時撤銷並重新授權。 |
| Flutter 找不到 Android SDK | 執行 `flutter config --android-sdk D:\Android\Sdk`。 |
| `python` 開不了 | 安裝官方 Python，勾選 Add Python to PATH，重新開終端機。 |
| 無法啟用 `.venv` | 對 CurrentUser 執行 `Set-ExecutionPolicy RemoteSigned`。 |

---

## 10. 最終驗收清單

完成下列命令，代表環境可開發本專案：

```powershell
flutter doctor -v
adb devices
cd D:\ai_diet_coach\mobile
flutter test
flutter run

cd D:\ai_diet_coach\backend
.\.venv\Scripts\Activate.ps1
pytest
```

參考資料：

- [Flutter 手動安裝](https://docs.flutter.dev/install/manual)
- [Flutter Android 開發設定](https://docs.flutter.dev/platform-integration/android/setup)
- [Flutter PATH 設定](https://docs.flutter.dev/install/add-to-path)
- [FastAPI 虛擬環境](https://fastapi.tiangolo.com/virtual-environments/)
- [Python Windows 文件](https://docs.python.org/3/using/windows.html)
