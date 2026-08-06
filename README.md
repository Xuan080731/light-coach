# AI Diet Coach MVP

AI 減重 App MVP：Flutter（Material Design 3）行動端 + Python FastAPI 後端。

## 專案結構

```text
mobile/   Flutter UI（Material Design 3）
backend/  FastAPI；AI 食物辨識與教練功能的安全 API 入口
```

## 啟動行動端

安裝 Flutter SDK 後：

```powershell
cd D:\ai_diet_coach\mobile
flutter create .
flutter pub get
flutter run
```

## 啟動 Python 後端

安裝 Python 3.11+ 後：

```powershell
cd D:\ai_diet_coach\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API 文件：`http://127.0.0.1:8000/docs`

> API key 只應放在後端的環境變數，絕不可寫進 Flutter App 或 Git。
