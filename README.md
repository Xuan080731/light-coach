# 輕盈教練 Light Coach

輕盈教練是一款以 Flutter 製作的 Android 飲食、體重與活動紀錄 App。1.0.0 版支援手動或 AI 圖片分析餐點、營養分數、減重目標、Health Connect、餐點提醒及本機備份。

> 本 App 僅供一般健康管理與紀錄，不提供醫療診斷、處方或專業營養治療。

## 主要功能

- 記錄餐點、份量、熱量與主要營養素
- 計算每日營養分數與目標進度
- 讀取 Health Connect 的步數與活動消耗熱量
- 使用自選 AI 供應商分析餐點、建立計畫與產生一般健康建議
- API 金鑰保存在 Android 安全儲存區
- 匯出、匯入本機 JSON 備份
- Material 3、動態色彩、深色模式與餐點提醒

## 隱私與網路

一般紀錄保存在裝置內，專案沒有廣告、分析追蹤或開發者營運的資料蒐集服務。只有在使用者主動使用 AI 功能時，選取的圖片及相關飲食、身體或活動資料才會直接傳送至使用者設定的 AI 供應商或 HTTPS 相容 API。

匯出的 JSON 備份未加密，使用者應自行妥善保存。詳細內容請閱讀 [隱私說明](PRIVACY.md)、[安全政策](SECURITY.md) 與 [1.0.0 安全稽核](SECURITY_AUDIT.md)。

## 專案結構

```text
mobile/   Flutter 3.44.8 / Dart 3.12 Android App
backend/  選用的 FastAPI 本機原型；目前行動 App 不依賴此服務
```

## 開發環境

- Flutter 3.44.8 stable
- Dart 3.12.2
- Java 17
- Android SDK
- Python 3.11 以上（僅選用的後端原型需要）

從儲存庫根目錄啟動 App：

```powershell
cd mobile
flutter pub get
flutter run
```

執行檢查：

```powershell
cd mobile
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

### 正式 Android 簽章

正式版必須使用專屬簽章，缺少簽章設定時 release build 會直接停止。請先在本機建立 `mobile/android/keystore/light-coach-release.jks`，再將 `mobile/android/key.properties.example` 複製為 `mobile/android/key.properties` 並填入密碼。這兩個私密檔案都已被 Git 忽略，請另外離線備份；遺失金鑰後將無法以相同 App 身分發布更新。

完成設定後執行：

```powershell
cd mobile
flutter build apk --release
```

選用後端原型：

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API 文件位於 `http://127.0.0.1:8000/docs`。此原型沒有正式環境所需的驗證與速率限制，請勿直接暴露到網際網路。

## AI 設定

使用者在 App 的「設定 → AI 服務設定」自行選擇 OpenAI、Gemini、Anthropic 或 HTTPS OpenAI 相容 API，並輸入自己的金鑰。金鑰不得寫入原始碼、環境範例、Issue、截圖或 Git 提交。

## 參與開發

請先閱讀 [CONTRIBUTING.md](CONTRIBUTING.md)。1.0.0 的變更請見 [CHANGELOG.md](CHANGELOG.md)。發現資安問題時不要建立公開 Issue，請依 [SECURITY.md](SECURITY.md) 私下回報。

## 授權

本專案以 [Apache License 2.0](LICENSE) 開源，允許個人及商業使用、修改與散布；散布時請保留授權與著作權聲明。完整內容請見 [LICENSE](LICENSE) 及 [NOTICE](NOTICE)。
