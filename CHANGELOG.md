# Changelog

本專案依循 Semantic Versioning。

## 1.0.0 - 2026-08-19

### 新增

- 飲食、份量、熱量及主要營養素紀錄
- 每日營養分數、營養分析及 AI 建議
- AI 餐點圖片分析與減重計畫
- Health Connect 步數與活動消耗熱量整合
- 體重紀錄、目標設定、主題及餐點提醒
- 首次使用引導與本機 JSON 備份還原
- 正式 Android application ID：`io.github.xuan080731.lightcoach`

### 安全與隱私

- API 金鑰使用 Android 加密安全儲存區
- AI API 強制 HTTPS，官方供應商限制官方網域
- 停止跨網域重新導向並限制外部回應大小
- 限制備份檔大小與格式版本
- 停用敏感 App 資料的 Android 自動備份
- 正式建置不再使用 Android debug 簽章
- 升級 pytest 至 9.0.3，修正 GHSA-6w46-j5rx-g56g
