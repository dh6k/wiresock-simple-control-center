# WireSock Simple Control Center

Một bộ script `.bat` cho Windows để điều khiển **WireSock Secure Connect** nhanh bằng CLI, đồng thời giữ các thao tác nguy hiểm như reconnect, đổi profile và chỉnh split tunneling có timeout/rollback rõ ràng.

Repo có hai cách dùng:

- **`WireSock-Control-Center.bat`**: bản all-in-one, có dashboard và menu.
- **`standalone/`**: từng chức năng tách riêng, dùng khi chỉ cần một tác vụ cụ thể.

> Các script này không thay thế WireSock. Chúng gọi `wiresock-connect-cli.exe` và đọc một số giá trị từ `wiresock.config` để đồng bộ trạng thái với WireSock Secure Connect.

## Dashboard hiện tại

```text
============================================================
                WireSock Control Center
============================================================

VPN Status       : Connected
WireSock GUI     : ON
Active Profile   : wg-SG-FREE-14
Profiles         : 6
Split Tunneling  : ON
Kill Switch      : OFF
Connect Timeout  : 15 seconds

[1] Toggle VPN
[2] Toggle Split Tunneling
[3] Switch Profile
[4] Check Installation Status
[5] Set Connection Timeout
[6] Toggle WireSock GUI
[7] Profile Manager
[8] Run Startup Monitor
[0] Exit
```

## Cấu trúc repo

```text
wiresock-simple-control-center/
├─ WireSock-Control-Center.bat
├─ WireSock-Control-Center.ini        # tạo khi chỉnh timeout, bị gitignore
├─ logs/                              # tạo lúc chạy startup monitor, *.log bị gitignore
├─ README.md
├─ .gitignore
└─ standalone/
   ├─ Install-WireSock-and-Add-PATH.bat
   ├─ Toggle-VPN.bat
   ├─ Toggle-Global-Split-Tunneling.bat
   ├─ Switch-Profile.bat
   ├─ Check-Installation.bat
   ├─ Toggle-WireSock-GUI.bat
   ├─ Profile-Manager.bat
   └─ Startup-Monitor.bat
```

## Yêu cầu

- Windows 10/11.
- PowerShell có sẵn trong Windows.
- WireSock Secure Connect đã được cài đặt, hoặc dùng script cài đặt trong `standalone/`.
- `wiresock-connect-cli.exe` nằm trong `PATH` hoặc một trong các vị trí thường dùng:

```text
C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe
C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe
```

Control Center tự xin quyền Administrator vì một số thao tác cần sửa file trong `ProgramData` hoặc cleanup trạng thái network.

## Cài WireSock và thêm CLI vào PATH

Chạy:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Script dùng package WinGet:

```text
NTKERNEL.WireSockVPNClient
```

và thêm thư mục CLI vào System PATH nếu cần.

---

# Startup Monitor / Preflight

Control Center bây giờ **không nhảy thẳng vào menu**. Sau khi UAC elevation và `pushd` về đúng thư mục script, nó chạy một preflight read-only trước.

Ví dụ:

```text
============================================================
           WireSock Control Center - Preflight
============================================================

[OK]   Script directory : D:\tools\wiresock-simple-control-center\
[OK]   WireSock CLI    : C:\Program Files\...\wiresock-connect-cli.exe
[OK]   Config file     : FOUND
[OK]   Active profile  : wg-SG-FREE-14
[OK]   Split tunneling : ON
[OK]   Profiles        : 6
[OK]   VPN status      : Connected
[OK]   WireSock GUI    : OFF
[OK]   Connect timeout : 15 seconds

Log: ...\logs\startup-20260819-173400.log

Starting Control Center...
```

Preflight kiểm tra:

- thư mục script sau UAC;
- WireSock CLI;
- `wiresock.config`;
- active profile;
- global Split Tunneling;
- số lượng profile CLI nhìn thấy;
- trạng thái VPN;
- trạng thái WireSock GUI;
- connection timeout hiện tại.

### Mục đích

Nó giúp phát hiện ngay các lỗi kiểu:

- clone repo sang folder khác rồi path bị sai;
- CLI không nằm trong PATH;
- WireSock chưa tạo config;
- service/CLI không trả status;
- không còn profile;
- GUI executable không dò được.

Startup Monitor **không đổi VPN, profile hay setting**. Nó chỉ đọc và ghi log.

Log được tạo trong:

```text
logs\startup-YYYYMMDD-HHMMSS.log
```

Có thể chạy lại bất kỳ lúc nào từ:

```text
[8] Run Startup Monitor
```

hoặc chạy bản riêng:

```text
standalone\Startup-Monitor.bat
```

---

# 1. Toggle VPN

Khi VPN đang `Connected` hoặc `Connecting`:

```text
Toggle VPN
   ↓
disconnect async
   ↓
poll status
   ↓
Disconnected / NotConnected
```

Khi VPN đang tắt:

```text
Toggle VPN
   ↓
đọc ActiveConfig
   ↓
connect ActiveConfig async
   ↓
poll status mỗi giây
   ↓
Connected hoặc timeout
```

Nếu connection lỗi và Kill Switch trong config đang OFF, script có thể gọi:

```bat
wiresock-connect-cli reset-network-lock
```

để tránh để lại stale network lock ngoài ý muốn.

---

# 2. Toggle Global Split Tunneling

Control Center đọc node:

```xml
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
```

trong:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

Nó chỉ đổi `True ↔ False` cho node đó.

Script **không sửa** danh sách tunneled applications/networks của bạn và không clone profile chỉ để mô phỏng split tunneling.

Nếu VPN đang kết nối:

```text
disconnect
   ↓
backup wiresock.config
   ↓
đổi EnableSplitTunnelingGlobally
   ↓
verify lại XML
   ↓
reconnect ActiveConfig
```

Nếu reconnect thất bại, backup được phục hồi và Control Center thử trả connection về trạng thái trước đó.

Backup all-in-one dùng:

```text
wiresock.config.control-center-backup
```

---

# 3. Switch Profile

Danh sách profile được lấy từ:

```bat
wiresock-connect-cli list
```

Ví dụ:

```text
[1] p1bla6-SG-FREE-18
[2] wg-SG-FREE-14 [ACTIVE]
[3] wg-SG-FREE-3
[4] wg-SG-FREE-6
```

Flow:

```text
chọn profile
    ↓
disconnect tunnel cũ nếu cần
    ↓
backup config
    ↓
đổi <ActiveConfig>
    ↓
connect profile mới ở background
    ↓
poll status tới Connected hoặc timeout
```

Nếu profile mới không connect được:

```text
cleanup failed connection
    ↓
reset stale network lock nếu Kill Switch OFF
    ↓
restore config cũ
    ↓
connect lại profile cũ
```

## Vì sao `connect` phải chạy async

Không gọi `connect ... -exit` đồng bộ rồi mới timeout.

Control Center dùng kiểu:

```bat
start "" /b "%CLI%" connect "profile" -log-level error -network-lock off -exit
```

sau đó tự poll:

```bat
wiresock-connect-cli status
```

Lý do là `-exit` chỉ thoát khi connection đạt trạng thái `Connected`. Nếu WireSock mắc ở `Connecting`, một call đồng bộ có thể giữ luôn BAT trước khi timeout của script được chạy.

---

# 4. Check Installation Status

Mục này kiểm tra:

- WinGet;
- WireSock CLI và path thực tế;
- CLI có nằm trong `PATH` hay không;
- WireSock GUI executable;
- GUI đang ON/OFF;
- `wiresock.config`;
- thư mục Profiles;
- số profile;
- active profile;
- Split Tunneling;
- Kill Switch;
- VPN status;
- connection timeout;
- đường dẫn startup log gần nhất trong phiên hiện tại.

Bản standalone:

```text
standalone\Check-Installation.bat
```

---

# 5. Connection Timeout

Mặc định:

```text
15 seconds
```

Có thể chỉnh từ **5 đến 120 giây** ở:

```text
[5] Set Connection Timeout
```

Giá trị được lưu cạnh BAT:

```text
WireSock-Control-Center.ini
```

Ví dụ:

```ini
CONNECT_TIMEOUT=15
```

File này không được commit lên repo.

---

# 6. Toggle WireSock GUI

`Toggle WireSock GUI` chỉ thao tác với process giao diện.

Control Center dò executable theo hai tầng:

1. shortcut WireSock Secure Connect trong Start Menu;
2. fallback sang các thư mục cài WireSock thường dùng và lọc executable theo ProductName/FileDescription.

Khi GUI đang OFF:

```text
resolve GUI executable
   ↓
explorer.exe "...\WireSock GUI.exe"
```

Khi GUI đang ON, script chỉ stop process có **đúng executable path đã resolve**, thay vì `taskkill *wiresock*`.

Mục tiêu là không vô tình dừng service/tunnel chỉ vì muốn đóng cửa sổ GUI.

Bản standalone:

```text
standalone\Toggle-WireSock-GUI.bat
```

---

# 7. Profile Manager

Profile Manager mới có trong Control Center và dưới dạng standalone:

```text
standalone\Profile-Manager.bat
```

Menu:

```text
============================================================
                 WireSock Profile Manager
============================================================

Active Profile : wg-SG-FREE-14
Profiles       : 6

[1] List Profiles
[2] Import Profile (.conf)
[3] Export Profile
[4] View Profile
[5] Duplicate Profile
[6] Rename Profile
[7] Delete Profile
[8] Open Profiles Folder
[0] Back
```

## List Profiles

Dùng CLI:

```bat
wiresock-connect-cli list
```

và đánh dấu profile khớp `ActiveConfig` bằng `[ACTIVE]`.

## Import Profile

Mở Windows file picker và gọi:

```bat
wiresock-connect-cli import "D:\VPN\profile.conf"
```

Theo tài liệu CLI hiện tại của WireSock, tên profile import được lấy từ **tên file không có extension**, và import sẽ fail nếu profile cùng tên đã tồn tại.

## Export Profile

Chọn profile và vị trí lưu bằng Save File dialog, sau đó gọi:

```bat
wiresock-connect-cli export "PROFILE" "D:\Backup\PROFILE.conf"
```

CLI WireSock không overwrite file đã có, nên Control Center dùng overwrite confirmation của Save dialog rồi xóa target cũ trước khi gọi export.

## View Profile

View không đọc trực tiếp file trong `ProgramData`.

Flow:

```text
export profile vào %TEMP%
   ↓
mở bằng Notepad
   ↓
đóng Notepad
   ↓
xóa bản temp
```

Như vậy nội dung profile, bao gồm key nếu có, không bị in ra console hay startup log.

## Duplicate Profile

WireSock CLI không có command `duplicate` riêng.

Control Center xây thao tác này từ primitive đã được CLI hỗ trợ:

```text
export profile nguồn
   ↓
lưu temp dưới NEW_NAME.conf
   ↓
import NEW_NAME.conf
   ↓
verify NEW_NAME xuất hiện trong list
```

Cơ chế này dựa trên hành vi được WireSock tài liệu hóa: **import profile name được derive từ filename**.

## Rename Profile

CLI hiện tại cũng không có `rename` riêng, nên rename được thực hiện theo kiểu transactional-ish:

```text
export OLD
   ↓
import bản copy với NEW_NAME.conf
   ↓
verify NEW_NAME tồn tại
   ↓
delete OLD
```

Nếu bước xóa OLD thất bại, script cố xóa NEW để rollback.

### Safety rule

Control Center **không cho rename profile đang active**. Hãy switch sang profile khác trước để tránh `ActiveConfig` trỏ vào một profile vừa bị xóa.

## Delete Profile

Dùng:

```bat
wiresock-connect-cli delete "PROFILE"
```

Script yêu cầu nhập:

```text
DELETE
```

để xác nhận.

Control Center **không cho delete profile đang active**.

## Open Profiles Folder

Mở thư mục WireSock profile được tài liệu hóa tại:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\Profiles
```

---

# File config được đọc

Control Center đọc:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

Các node đang được sử dụng:

```xml
<ActiveConfig>wg-SG-FREE-14</ActiveConfig>
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
<EnableKillSwitch>False</EnableKillSwitch>
```

`ActiveConfig` và `EnableSplitTunnelingGlobally` được sửa ở những thao tác tương ứng. `EnableKillSwitch` chỉ được đọc để Control Center quyết định cách connect/cleanup network lock.

---

# Recovery khi Internet bị block ngoài ý muốn

Nếu một connection lỗi và Internet vẫn bị block trong khi bạn không chủ ý bật Kill Switch, mở Terminal/CMD bằng Administrator:

```bat
wiresock-connect-cli disconnect
wiresock-connect-cli reset-network-lock
```

Sau đó connect lại profile tốt:

```bat
wiresock-connect-cli connect "PROFILE_NAME" -exit
```

Nếu Kill Switch đang được bật có chủ ý, `reset-network-lock` sẽ gỡ network lock đó, nên không nên dùng như một nút chữa bách bệnh.

---

# Các script standalone

| File | Chức năng |
|---|---|
| `Install-WireSock-and-Add-PATH.bat` | Cài WireSock qua WinGet và thêm CLI vào System PATH |
| `Toggle-VPN.bat` | Bật/tắt VPN theo ActiveConfig |
| `Toggle-Global-Split-Tunneling.bat` | Toggle global split tunneling và reconnect nếu cần |
| `Switch-Profile.bat` | Đổi ActiveConfig + async connect + timeout/rollback |
| `Check-Installation.bat` | Diagnostic cài đặt/trạng thái |
| `Toggle-WireSock-GUI.bat` | Bật/tắt riêng GUI process |
| `Profile-Manager.bat` | List/import/export/view/duplicate/rename/delete profile |
| `Startup-Monitor.bat` | Preflight read-only để kiểm tra WireSock trước khi thao tác |

---

# Quick start

Clone repo:

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
```

Nếu WireSock chưa cài:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Sau đó:

```text
WireSock-Control-Center.bat
```

Control Center sẽ tự elevate, cố định working directory về thư mục repo, chạy Startup Monitor, rồi mới mở menu.

---

# Tài liệu WireSock tham chiếu

Triển khai CLI profile manager dựa trên tài liệu WireSock Secure Connect hiện tại, trong đó CLI hỗ trợ `list`, `import`, `export`, `delete`, và quy định profile import lấy tên từ filename:

- https://www.wiresock.net/documentation/wiresock-secure-connect/wiresock-connect-cli.html
- https://www.wiresock.net/documentation/wiresock-secure-connect/connection-profiles.html
- https://v3.wiresock.net/documentation/wiresock-secure-connect/application-initialization-issues.html

Tài liệu được kiểm tra lại khi cập nhật tính năng này vào ngày **2026-08-19**.
