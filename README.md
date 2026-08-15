# Server Log 練習筆記

這個資料夾是用來練習 Linux shell 與 `grep` 查詢 log 的範例資料。

## 資料夾內容

- `ICT/`：ICT 測試站假 log
- `FCT1/`：FCT1 測試站假 log
- `FCT2/`：FCT2 測試站假 log
- `check_server_logs.sh`：快速統計與查詢 log 的 shell 腳本

每個 log 檔會包含類似以下資訊：

```text
station=FCT1
server_id=SERVER-0023
test_result=FAIL
error_code=E3002_FAN_FAIL
```

## 基本 grep 練習

搜尋所有錯誤碼：

```bash
grep -Rni "error_code" .
```

搜尋 FAIL 的 log：

```bash
grep -Rni "test_result=FAIL" .
```

只列出有錯誤碼的檔案名稱：

```bash
grep -Rli "error_code" .
```

把查詢結果寫入新的 txt：

```bash
grep -Rni "error_code" . > error_report.txt
```

## 執行 shell 腳本

在 Git Bash 或 WSL 中執行：

```bash
cd "/mnt/c/Users/su622/Desktop/Server log"
bash check_server_logs.sh
```

或從任何位置直接執行：

```bash
bash "/mnt/c/Users/su622/Desktop/Server log/check_server_logs.sh"
```

## 學習重點

- `grep -R`：遞迴搜尋資料夾
- `grep -n`：顯示符合內容的行號
- `grep -i`：忽略大小寫
- `>`：覆蓋寫入檔案
- `>>`：追加寫入檔案
- `wc -l`：統計行數
- `$(command)`：執行指令並取回結果

這份資料可以用來練習「100 台 Server 出問題時，如何快速從大量 log 中找出 error code 並產生報告」。
