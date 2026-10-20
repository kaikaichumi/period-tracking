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
  - 週期規律性分析
- **智慧預測**：依最近幾個週期預測未來三次經期日期，並顯示誤差範圍；經期晚來時會顯示延遲天數
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
  - 手動建立備份到自己 Google Drive 的 App 私人資料夾
  - 可從備份清單選擇要還原的版本
  - 換手機時透過備份移轉資料（不會自動同步）
<img src="https://github.com/user-attachments/assets/29a1c209-d9d2-47f5-80da-b4b155d52563" width="30%" alt="1044309_0">

## 🛠️技術架構

### 開發環境
- **框架**：Flutter
- **平台**：Android、iOS
- **語言**：Dart
- **資料儲存**：本地儲存 + Google 雲端備份

### 主要套件
本專案使用以下 Flutter 套件：
- **狀態管理**：provider
- **本地儲存**：shared_preferences
- **雲端備份**：google_sign_in、googleapis（Google Drive API）
- **提醒通知**：flutter_local_notifications
- **日曆介面**：table_calendar
- **UI 元件**：Material Design 3

## 📦 安裝說明

### 環境需求
- Flutter 3.47.7（stable）以上
- Android Studio / VS Code
- Android SDK
- iOS：macOS、Xcode 26 以上、CocoaPods（App 支援 iOS 15 以上的 iPhone）
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

Android：

    flutter build apk --release

iOS（需在 Mac 上執行）：

    flutter build ipa --release

第一次建置前，請用 Xcode 開啟 `ios/Runner.xcworkspace`，在 Runner 的 Signing & Capabilities 選擇你的 Apple Developer Team。產生的 `build/ios/ipa/*.ipa` 可用 Transporter 或 Xcode Organizer 上傳到 App Store Connect。

### iOS 的 Google Drive 備份

iOS 版需要自己的 OAuth 用戶端，沒有設定時設定頁不會出現 Google 登入。

1. 在 Android 版使用的同一個 Google Cloud 專案中，建立「iOS」類型的 OAuth 用戶端，套件 ID 填 `com.techcare.lunacare`。必須是同一個專案，iOS 才讀得到 Android 版建立的備份。
2. 把用戶端 ID 填進 `lib/utils/constants.dart` 的 `googleIosClientId`。
3. 在 `ios/Runner/Info.plist` 加上反轉後的用戶端 ID 作為網址配置，否則登入時 App 會閃退：

        <key>CFBundleURLTypes</key>
        <array>
            <dict>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>com.googleusercontent.apps.你的用戶端ID前綴</string>
                </array>
            </dict>
        </array>

`flutter test` 會檢查這兩處是否一致。

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
1. **記錄月經**：點選日期後按「標記為經期」，或用右上角的範圍選擇一次標記多天
2. **記錄症狀**：選擇相應症狀並新增備註
3. **查看預測**：在分析頁面查看下次週期預測
4. **數據備份**：定期使用 Google 雲端備份功能

## 🔒 隱私與安全

- **只存在本機**：記錄只儲存在裝置上，也不會隨 Android 系統自動備份上傳；iOS 則會依你的 iCloud 備份設定，把 App 資料放進裝置備份
- **傳輸加密**：手動備份透過 HTTPS 上傳到你的 Google Drive App 私人資料夾（備份檔本身沒有另外加密）
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
