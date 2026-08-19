# 輕盈教練 1.0.0 安全稽核

稽核日期：2026 年 8 月 19 日

## 範圍

- Flutter / Android 原始碼與發布設定
- AI API 金鑰、端點及外部網路回應處理
- Health Connect、飲食與身體資料的本機保存及備份
- Python FastAPI 原型
- Git 歷史、目前工作目錄及鎖定相依套件的機密與已知弱點

## 已修正

### 中度：AI 金鑰可能傳送至不安全或錯誤的端點

原本所有供應商的 API 基底網址皆可編輯，且未強制 HTTPS。現在官方供應商只允許官方網域，自訂服務只允許有效 HTTPS 基底網址；Android 也明確禁止明文網路流量。

### 中度：外部重新導向可能改變 API 請求目的地

AI HTTP 請求現在停用自動重新導向，避免驗證標頭跟隨非預期端點。

### 中度（隱私）：Android 自動備份可能包含健康與飲食資料

App 已停用 Android 雲端備份及裝置轉移備份。API 金鑰原本即使用 Android 加密安全儲存區，且不會加入 JSON 備份。

### 中度（發布）：release build 使用 debug 簽章

Gradle 已移除 debug 簽章 fallback；缺少正式 `key.properties` 時 release build 會直接停止。正式 APK 發布前仍必須建立並妥善備份專用簽章金鑰。

### 中度（開發工具）：pytest 暫存目錄弱點

OSV 偵測到 `pytest 8.3.4` 受 GHSA-6w46-j5rx-g56g 影響，已升級至修補版本 9.0.3。此套件只用於後端測試，不會打包進 Android App。

### 低度：外部回應與備份檔缺少大小限制

AI 回應及 JSON 備份均限制為 2 MB，備份格式版本也會在還原前驗證，降低記憶體耗盡與異常資料風險。

### 低度：敏感資料流向說明不完整

AI 設定頁與 `PRIVACY.md` 現在明確說明：API 金鑰及使用者主動提供的資料會傳送至所選 AI 供應商或自訂 HTTPS API；匯出的 JSON 備份未加密。

## 尚未消除的風險與使用限制

- 飲食、體重、活動及 AI 對話使用 Android App 沙箱內的偏好儲存，未另外使用資料庫層加密。已停用系統備份，但已取得 root 權限或已遭入侵的裝置仍可能讀取 App 資料。
- JSON 備份設計為可攜式明文格式。App 會顯示警告，使用者需自行安全保存。
- AI 內容與資料處理由使用者選擇的第三方供應商決定；App 無法控制供應商端的保存與模型輸出。
- `backend/` 沒有身分驗證及速率限制，只能作為本機原型；未完成額外防護前不得公開部署。
- AI 產生的健康建議可能不準確，不能作為醫療診斷或處方。

## 檢查結果

- 機密掃描：未發現硬編碼 API 金鑰、GitHub/GitLab token 或私鑰。
- OSV Pub 掃描：116 個鎖定套件未發現已知公告。
- OSV PyPI 掃描：升級 pytest 後，4 個鎖定套件未發現已知公告。
- Android debug APK：建置成功。
- Flutter widget tests：18 項全部通過。
- Flutter analyze：沒有 error 或 warning；有 34 個 info 級 API 淘汰與程式風格提示。

## 後續建議

- 每次發布前執行 GitHub Dependabot、Flutter analyze/test 及 OSV 掃描。
- 未來若儲存更多健康資料，改用具有資料庫層加密及遷移機制的儲存方案。
- 若部署後端，先加入驗證、速率限制、TLS、請求大小限制、監控及祕密管理。
