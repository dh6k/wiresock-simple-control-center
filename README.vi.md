# WireSock Simple Control Center

Một bộ script `.bat` cho Windows để điều khiển **WireSock Secure Connect** nhanh hơn bằng CLI, nhưng vẫn giữ các thao tác quan trọng như reconnect, đổi profile, split tunneling và network-lock cleanup có timeout/rollback rõ ràng.

Repo có hai cách dùng:

- **`WireSock-Control-Center.bat`**: bản all-in-one, có dashboard và menu.
- **`standalone/`**: từng chức năng tách riêng, tiện khi chỉ cần một thao tác cụ thể.

## Tính năng

- Bật / tắt VPN.
- Bật / tắt **Global Split Tunneling**.
- Chuyển profile và tự reconnect.
- Bật / tắt WireSock GUI.
- Profile Manager: list, import, export, view, duplicate, rename, delete.
- Startup Monitor / Preflight trước khi vào Control Center.
- Kiểm tra WireSock, CLI, PATH, config, profile và trạng thái kết nối.
- Timeout khi connect, mặc định **15 giây**, có thể chỉnh từ **5 đến 120 giây**.
- Rollback profile/config khi reconnect thất bại.
- Cleanup stale network lock khi Kill Switch đang OFF.

---

# Yêu cầu

- Windows 10 hoặc Windows 11.
- PowerShell có sẵn trong Windows.
- Quyền Administrator khi script yêu cầu.
- WireSock Secure Connect.
- Khuyến nghị có **WinGet** nếu muốn dùng installer tự động.
- Khuyến nghị có **Git** nếu muốn clone và cập nhật repo bằng `git pull`.

WireSock CLI thường nằm tại:

```text
C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe
```

Control Center cũng có fallback cho biến thể path có chữ `WireSock` viết hoa khác nhau.

---

# Cài đặt

## Cách 1: Cài tự động bằng script đi kèm

Đây là cách dễ nhất nếu máy chưa có WireSock.

### Bước 1: tải repo

Nếu đã có Git:

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
```

Nếu không dùng Git, tải repo dưới dạng ZIP từ GitHub rồi **giải nén hoàn toàn** trước khi chạy BAT. Không nên chạy trực tiếp BAT bên trong file ZIP.

### Bước 2: chạy installer

Mở:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Script sẽ tự xin quyền Administrator rồi thực hiện hai việc:

1. Cài WireSock bằng WinGet:

```bat
winget install NTKERNEL.WireSockVPNClient --accept-package-agreements --accept-source-agreements
```

2. Thêm thư mục CLI này vào **System PATH** nếu chưa có:

```text
C:\Program Files\Wiresock Secure Connect\command-line
```

Script tránh thêm PATH trùng và không dùng cách ghi PATH kiểu dễ cắt cụt giá trị dài.

### Bước 3: mở terminal mới

Sau khi cài xong, đóng CMD / PowerShell cũ rồi mở cửa sổ mới để ứng dụng mới nhận PATH đã cập nhật.

Kiểm tra:

```bat
where wiresock-connect-cli.exe
```

Nếu thành công, Windows sẽ trả về đường dẫn tới `wiresock-connect-cli.exe`.

Có thể kiểm tra thêm:

```bat
wiresock-connect-cli status
```

### Bước 4: mở WireSock ít nhất một lần

Khuyến nghị mở WireSock Secure Connect và tạo/import ít nhất một profile trước khi chạy Control Center.

Control Center đọc một số trạng thái từ:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

Nếu WireSock chưa từng khởi tạo config hoặc chưa có profile, một số mục sẽ báo `UNKNOWN` / `NOT FOUND`.

### Bước 5: chạy Control Center

Double-click:

```text
WireSock-Control-Center.bat
```

Script sẽ tự yêu cầu UAC nếu cần. Sau khi elevate, nó chạy **Startup Monitor / Preflight** trước rồi mới vào menu chính.

---

## Cách 2: Cài WireSock thủ công

Nếu không muốn dùng installer BAT:

### 1. Cài WireSock bằng WinGet

Mở Terminal / PowerShell:

```bat
winget install NTKERNEL.WireSockVPNClient
```

### 2. Kiểm tra CLI

```bat
where wiresock-connect-cli.exe
```

Nếu CLI chưa nằm trong PATH nhưng file tồn tại tại:

```text
C:\Program Files\Wiresock Secure Connect\command-line
```

thì có thể chạy riêng:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Script sẽ phát hiện package đã có và vẫn tiếp tục phần PATH setup.

### 3. Clone repo

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
```

### 4. Chạy kiểm tra trước

Có thể chạy:

```text
standalone\Check-Installation.bat
```

hoặc:

```text
standalone\Startup-Monitor.bat
```

Nếu các mục chính đều `OK`, chạy:

```text
WireSock-Control-Center.bat
```

---

# Cập nhật

Nếu cài bằng Git:

```bat
cd wiresock-simple-control-center
git pull
```

Sau đó chạy lại BAT như bình thường.

Nếu tải ZIP thủ công, tải bản mới và thay thư mục cũ. File local sau đây không cần copy vào repo vì nó được tạo lại tự động:

```text
WireSock-Control-Center.ini
```

---

# Sử dụng Control Center

Dashboard hiện tại có dạng:

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

## [1] Toggle VPN

Nếu VPN đang `Connected` / `Connecting`, script sẽ disconnect.

Nếu VPN đang `Disconnected` / `NotConnected`, script đọc `ActiveConfig` rồi connect lại profile đó.

Connect được chạy ở background và script tự poll trạng thái, nên timeout vẫn hoạt động kể cả khi WireSock mắc ở `Connecting`.

## [2] Toggle Split Tunneling

Toggle đúng global setting:

```xml
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
```

thành `False` hoặc ngược lại.

Script **không sửa danh sách app/IP split tunneling**.

Nếu VPN đang chạy:

```text
disconnect
→ backup config
→ toggle setting
→ reconnect ActiveConfig
```

Nếu reconnect fail, script cố restore config trước đó.

## [3] Switch Profile

Hiển thị danh sách profile đánh số:

```text
[1] wg-SG-FREE-14 [ACTIVE]
[2] wg-SG-FREE-3
[3] wg-SG-FREE-6
```

Chọn profile mới sẽ thực hiện:

```text
disconnect profile hiện tại
→ đổi ActiveConfig
→ connect profile mới
→ verify Connected
```

Nếu profile mới không connect trong timeout, script cleanup connection lỗi, restore config cũ và thử nối lại profile trước.

## [4] Check Installation Status

Kiểm tra nhanh:

- WinGet.
- WireSock CLI.
- CLI trong PATH.
- `wiresock.config`.
- WireSock GUI executable.
- VPN status.
- active profile.
- số lượng profile.
- Split Tunneling.
- Kill Switch.
- connection timeout.

Nếu mới setup máy, đây là mục nên chạy đầu tiên khi có gì đó không hoạt động như mong đợi.

## [5] Set Connection Timeout

Mặc định:

```text
15 seconds
```

Cho phép đặt từ:

```text
5 - 120 seconds
```

Setting được lưu trong:

```text
WireSock-Control-Center.ini
```

Ví dụ:

```ini
CONNECT_TIMEOUT=15
```

## [6] Toggle WireSock GUI

Chỉ bật / tắt process GUI WireSock, không chủ ý dừng VPN service.

Script tự dò executable WireSock GUI từ Start Menu hoặc thư mục cài đặt rồi xác định process tương ứng.

Standalone GUI toggle tự elevate nếu cần để có thể đóng GUI được chạy ở quyền cao hơn.

## [7] Profile Manager

Menu gồm:

```text
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

Một số lưu ý:

- `Import`: chọn file `.conf` bằng file picker.
- `Export`: chọn nơi lưu profile.
- `View`: export tạm rồi mở bằng Notepad.
- `Duplicate`: export + import dưới tên mới.
- `Rename`: tạo profile tên mới rồi xóa profile cũ sau khi verify.
- `Delete`: yêu cầu nhập `DELETE` để xác nhận.
- Không cho rename/delete profile đang active.

## [8] Run Startup Monitor

Chạy lại preflight mà Control Center đã chạy lúc khởi động.

Nó chỉ đọc trạng thái, không chủ ý thay đổi VPN/profile/settings.

Log nằm trong:

```text
logs\startup-YYYYMMDD-HHMMSS.log
```

---

# Các script Standalone

Nếu không muốn mở menu all-in-one, có thể chạy trực tiếp từng file trong `standalone/`.

| File | Chức năng |
|---|---|
| `Install-WireSock-and-Add-PATH.bat` | Cài WireSock qua WinGet + thêm CLI vào System PATH |
| `Toggle-VPN.bat` | Bật/tắt VPN bằng ActiveConfig |
| `Toggle-Global-Split-Tunneling.bat` | Bật/tắt Global Split Tunneling |
| `Switch-Profile.bat` | Chuyển profile và reconnect |
| `Check-Installation.bat` | Kiểm tra cài đặt / PATH / trạng thái |
| `Toggle-WireSock-GUI.bat` | Bật/tắt WireSock GUI |
| `Profile-Manager.bat` | Quản lý profile |
| `Startup-Monitor.bat` | Chạy preflight riêng |

Các standalone BAT được thiết kế để chạy độc lập và tự xử lý working directory sau khi clone repo sang vị trí khác.

---

# Cấu trúc repo

```text
wiresock-simple-control-center/
├─ WireSock-Control-Center.bat
├─ README.md
├─ .gitignore
├─ logs/                         # tạo khi chạy startup monitor
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

---

# File cấu hình được đọc

WireSock Control Center đọc:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

Các node chính:

```xml
<ActiveConfig>wg-SG-FREE-14</ActiveConfig>
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
<EnableKillSwitch>False</EnableKillSwitch>
```

- `ActiveConfig`: profile hiện được chọn.
- `EnableSplitTunnelingGlobally`: global Split Tunneling.
- `EnableKillSwitch`: được đọc để quyết định cách connect / cleanup network lock.

Trước khi sửa config ở các thao tác quan trọng, script có cơ chế tạo backup và rollback khi cần.

---

# Troubleshooting

## `wiresock-connect-cli.exe not found`

Kiểm tra:

```bat
where wiresock-connect-cli.exe
```

Nếu không có kết quả, chạy:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Sau đó mở terminal mới.

## `The system cannot find the path specified`

Đầu tiên cập nhật repo:

```bat
git pull
```

Các BAT hiện tại tự ép working directory về thư mục của chính script và có fallback temp directory để hạn chế lỗi path sau UAC / clone repo.

Nếu vẫn gặp lỗi, chạy:

```text
standalone\Startup-Monitor.bat
```

để xem path nào không được tìm thấy.

## VPN mắc ở `Connecting`

Control Center có timeout riêng. Khi timeout, nó cố cleanup tunnel lỗi và rollback profile/config nếu thao tác trước đó có thay đổi chúng.

Có thể giảm/tăng thời gian ở:

```text
[5] Set Connection Timeout
```

## Internet bị block sau connection lỗi

Nếu **Kill Switch không được bật có chủ ý**, mở CMD/Terminal bằng Administrator:

```bat
wiresock-connect-cli disconnect
wiresock-connect-cli reset-network-lock
```

Sau đó connect lại profile tốt.

Nếu Kill Switch đang bật có chủ ý, không nên dùng `reset-network-lock` như một nút chữa bách bệnh vì nó sẽ gỡ network lock.

## GUI toggle nhận sai trạng thái hoặc không đóng được GUI

Cập nhật repo trước:

```bat
git pull
```

Standalone GUI toggle hiện tự elevate và dùng executable/process thực tế của WireSock GUI để detect/terminate thay vì kill mù các process có chữ `wiresock`.

---

# Quick Start

Máy mới hoàn toàn:

```text
1. Clone / tải repo.
2. Chạy standalone\Install-WireSock-and-Add-PATH.bat.
3. Mở WireSock và tạo/import profile.
4. Chạy standalone\Check-Installation.bat.
5. Chạy WireSock-Control-Center.bat.
```

Máy đã có WireSock:

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
WireSock-Control-Center.bat
```

Để cập nhật sau này:

```bat
git pull
```

Một cửa sổ BAT nhỏ, vài phím số, và WireSock bớt phải được mở ra chỉ để bấm những công tắc lẽ ra đã có hotkey từ đầu.