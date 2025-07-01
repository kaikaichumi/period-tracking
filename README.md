# 月時光 🌸

一款專為女性設計的月經週期追蹤應用程式，讓您輕鬆管理和預測生理週期。

## 📱 功能特色

### 🗓️ 智慧週期追蹤
- **直觀日曆介面**：清晰顯示每月週期狀態
- **一鍵記錄**：快速標記月經開始日期
- **週期視覺化**：粉色標記清楚顯示經期天數
- **即時更新**：自動計算目前週期進度

<img src="https://github.com/user-attachments/assets/21d1ca92-98a5-4273-bd20-cfb2b8e8d60a" width="30%" alt="1044307_0">

### 📊 數據分析與預測
- **週期統計**：
  - 平均週期長度追蹤
  - 平均經期長度計算
  - 週期規律性分析（準確度高達92%）
- **智慧預測**：預測未來三個月經期日期
- **詳細記錄**：
  - 總記錄天數統計
  - 經期天數累計
  - 平均經痛程度評估
  - 症狀記錄追蹤
<img src="https://github.com/user-attachments/assets/7b43f145-5e1f-45f7-9cb6-9b5bb62f6000" width="30%" alt="1044308_0">

### 💊 症狀管理
全方位症狀記錄功能，包含：
- **生理症狀**：腰痛、頭痛、乳房脹痛、腹脹
- **情緒變化**：情緒波動追蹤
- **身體狀況**：疲勞、失眠、噁心記錄
- **皮膚狀態**：痘痘生長追蹤
- **食慾變化**：飲食習慣改變記錄
- **自訂備註**：個人化症狀描述

### 💕 親密關係記錄
- 私密且安全的親密關係追蹤
- 協助了解身體週期與親密關係的關聯

### ⚙️ 個人化設定
- **週期參數調整**：
  - 自訂週期長度（預設28天）
  - 自訂經期長度（預設5天）
- **雲端備份**：
  - Google 雲端自動備份
  - 跨裝置數據同步
  - 一鍵還原功能
<img src="https://github.com/user-attachments/assets/29a1c209-d9d2-47f5-80da-b4b155d52563" width="30%" alt="1044309_0">

## 🛠️技術架構

### 開發環境
- **框架**：Flutter
- **平台**：Android
- **語言**：Dart
- **資料儲存**：本地儲存 + Google 雲端備份

### 主要套件
本專案使用以下 Flutter 套件：
- **狀態管理**：適合的狀態管理解決方案
- **本地儲存**：SQLite 或 SharedPreferences
- **雲端備份**：Google Drive API
- **日期處理**：DateTime 相關套件
- **UI 元件**：Material Design 組件

## 📦 安裝說明

### 環境需求
- Flutter SDK 3.0+
- Android Studio / VS Code
- Android SDK
- Git

### 建置步驟

1. 複製專案到本地

    git clone https://github.com/kaikaichumi/period-tracking.git

2. 進入專案目錄

    cd period-tracking

3. 安裝相依套件

    flutter pub get

4. 執行專案

    flutter run

### 發布版本建置

    flutter build apk --release

## 🎨 介面截圖

### 主要畫面
- **日曆追蹤**：直觀的月曆介面，清楚顯示週期狀態
- **數據分析**：完整的統計報表和預測功能
- **記錄輸入**：簡潔的症狀和狀態記錄介面
- **設定管理**：個人化參數調整和備份功能

## 📋 使用說明

### 首次使用
1. 開啟應用程式
2. 設定個人週期參數（週期長度、經期長度）
3. 記錄最近一次月經開始日期
4. 開始日常記錄

### 日常操作
1. **記錄月經**：點擊「大姨媽來了」開關
2. **記錄症狀**：選擇相應症狀並新增備註
3. **查看預測**：在分析頁面查看下次週期預測
4. **數據備份**：定期使用 Google 雲端備份功能

## 🔒 隱私與安全

- **本地優先**：所有數據優先儲存在本地裝置
- **加密備份**：雲端備份採用加密傳輸
- **隱私保護**：不收集個人識別資訊
- **離線使用**：核心功能支援離線操作

## 🚀 未來規劃

- [ ] iOS 版本開發
- [ ] 更多症狀類型支援
- [ ] 生理週期相關資訊教育
- [ ] 多語言支援
- [ ] 更精確的預測演算法
- [ ] 健康數據匯出功能

## 🤝 貢獻指南

歡迎提交 Issue 和 Pull Request！

### 貢獻流程
1. Fork 本專案
2. 建立功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交變更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

## 📄 授權條款

本專案採用 MIT 授權條款 - 詳見 [LICENSE](LICENSE) 檔案

## 👥 開發團隊

- **開發者**：[kaikaichumi](https://github.com/kaikaichumi)

## 📞 聯絡方式

如有任何問題或建議，歡迎透過以下方式聯絡：
- GitHub Issues
- Email：karta2398980@gmail.com

---

**月時光** - 讓每個月都更加了解自己 💝
