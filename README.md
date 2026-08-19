# WireSock Control Center

Bộ script `.bat` để điều khiển **WireSock Secure Connect** trên Windows mà không phải mở GUI mỗi lần. Repo có một bản **all-in-one** và một thư mục `standalone/` chứa từng chức năng riêng để dùng độc lập.

> Các script được xây dựng dựa trên layout `wiresock.config` có các node `ActiveConfig`, `EnableSplitTunnelingGlobally` và `EnableKillSwitch`. Script không thay đổi danh sách app/IP split tunneling của bạn.

## Tính năng

`WireSock-Control-Center.bat` hiển thị một dashboard nhỏ:

```text
VPN Status       : Connected
Active Profile   : wg-SG-FREE-14
Split Tunneling  : ON
Kill Switch      : OFF
Connect Timeout  : 15 seconds

[1] Toggle VPN
[2] Toggle Split Tunneling
[3] Switch Profile
[4] Check Installation Status
[5] Set Connection Timeout
[0] Exit
```

Nó hỗ trợ:

- bật/tắt VPN bằng profile đang active;
- bật/tắt **global Split Tunneling**;
- chuyển profile bằng menu đánh số rồi tự connect profile mới;
- hiển thị `VPN Status`, `Active Profile`, `Split Tunneling`, `Kill Switch`;
- kiểm tra WireSock/CLI/WinGet/PATH/config;
- timeout connect tùy chỉnh, mặc định **15 giây**, phạm vi **5-120 giây**;
- rollback config/profile nếu thao tác connect thất bại;
- cleanup stale network lock khi Kill Switch đang tắt.

## Cấu trúc repo

```text
wiresock-simple-control-center/
├─ WireSock-Control-Center.bat
├─ README.md
├─ .gitignore
└─ standalone/
   ├─ Install-WireSock-and-Add-PATH.bat
   ├─ Toggle-VPN.bat
   ├─ Toggle-Global-Split-Tunneling.bat
   ├─ Switch-Profile.bat
   └─ Check-Installation.bat
```

## Yêu cầu

- Windows 10/11.
- PowerShell có sẵn trong Windows.
- WireSock Secure Connect.
- `wiresock-connect-cli.exe` trong `PATH` hoặc tại một trong các path:

```text
C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe
C:\Program Files\WireSock Secure Connect\command-line\wiresock-connect-cli.exe
```

Các thao tác sửa config và network sẽ tự xin quyền Administrator.

## Cài WireSock + thêm CLI vào PATH

Chạy:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Script dùng:

```bat
winget install NTKERNEL.WireSockVPNClient --accept-package-agreements --accept-source-agreements
```

sau đó thêm:

```text
C:\Program Files\Wiresock Secure Connect\command-line
```

vào **System PATH** nếu chưa tồn tại.

## File cấu hình WireSock được dùng

Các script đọc file:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

Ba giá trị quan trọng:

```xml
<ActiveConfig>wg-SG-FREE-14</ActiveConfig>
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
<EnableKillSwitch>False</EnableKillSwitch>
```

- `ActiveConfig`: profile được chọn.
- `EnableSplitTunnelingGlobally`: trạng thái switch **Apply split tunneling to all profiles**.
- `EnableKillSwitch`: dùng để quyết định có được tự cleanup network lock khi lỗi hay không.

## Vì sao connect chạy bất đồng bộ

Một phiên bản cũ từng gọi trực tiếp:

```bat
wiresock-connect-cli connect "profile" -exit
```

rồi mới chạy vòng timeout. Nếu CLI mắc ở trạng thái `Connecting`, chính lệnh `connect` có thể giữ BAT lại trước khi vòng timeout được chạy.

Bản hiện tại khởi động connect bằng:

```bat
start "" /b wiresock-connect-cli.exe connect "profile" ... -exit
```

sau đó poll:

```bat
wiresock-connect-cli status
```

mỗi giây. Nhờ vậy timeout thực sự có cơ hội hoạt động. Nếu quá thời gian cấu hình, script cleanup connection lỗi và cố gắng rollback.

## 1. Toggle VPN

Khi chọn `Toggle VPN`:

```text
Connected / Connecting
        ↓
     disconnect
        ↓
       OFF
```

Nếu VPN đang tắt:

```text
NotConnected / Disconnected
        ↓
đọc ActiveConfig
        ↓
connect profile đó
        ↓
poll tới Connected
```

Nếu connect timeout và `EnableKillSwitch=False`, script có thể chạy:

```bat
wiresock-connect-cli reset-network-lock
```

để cleanup network lock không mong muốn.

## 2. Toggle Global Split Tunneling

Chức năng này **không clone profile** và không sửa `AllowedApps`, `AllowedIPs`, `DisallowedApps` hay danh sách network.

Nó chỉ đổi đúng node:

```xml
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
```

thành `False`, hoặc ngược lại.

Nếu VPN đang chạy, flow là:

```text
disconnect
   ↓
backup wiresock.config
   ↓
True ↔ False
   ↓
verify XML
   ↓
reconnect ActiveConfig
```

Nếu reconnect thất bại, script restore backup cũ và thử phục hồi connection trước đó.

## 3. Switch Profile

Script lấy danh sách bằng:

```bat
wiresock-connect-cli list
```

và hiện menu:

```text
[1] p1bla6-SG-FREE-18
[2] wg-SG-FREE-14  [ACTIVE]
[3] wg-SG-FREE-3
[4] wg-SG-FREE-6
```

Khi chọn profile mới:

```text
disconnect tunnel hiện tại
        ↓
backup wiresock.config
        ↓
đổi <ActiveConfig>
        ↓
connect profile mới async
        ↓
poll status
```

Nếu profile mới không connect được trong timeout:

```text
cleanup failed connection
        ↓
reset network lock nếu Kill Switch OFF
        ↓
restore ActiveConfig cũ
        ↓
connect lại profile cũ
```

## 4. Check Installation Status

Dashboard kiểm tra:

- `winget.exe` có tồn tại hay không;
- package ID `NTKERNEL.WireSockVPNClient` có được WinGet nhận diện;
- vị trí `wiresock-connect-cli.exe`;
- CLI có nằm trong `PATH`;
- `wiresock.config` có tồn tại;
- active profile;
- trạng thái global split tunneling;
- Kill Switch;
- kết quả `wiresock-connect-cli status`.

Có bản riêng:

```text
standalone\Check-Installation.bat
```

## 5. Connection timeout

Bản all-in-one mặc định dùng:

```text
15 seconds
```

Có thể đổi từ menu `Set Connection Timeout`, phạm vi `5-120` giây.

Giá trị được lưu cạnh BAT:

```text
WireSock-Control-Center.ini
```

Ví dụ:

```ini
CONNECT_TIMEOUT=15
```

File này được `.gitignore` vì nó là setting local của từng máy.

## Các script standalone

### `Install-WireSock-and-Add-PATH.bat`

Chỉ cài WireSock qua WinGet và thêm thư mục CLI vào System PATH.

### `Toggle-VPN.bat`

Chỉ bật/tắt tunnel bằng `ActiveConfig`. Không sửa split tunneling hay profile list.

### `Toggle-Global-Split-Tunneling.bat`

Chỉ toggle `EnableSplitTunnelingGlobally` và reconnect khi cần.

### `Switch-Profile.bat`

Chỉ hiển thị profile menu, đổi `ActiveConfig`, rồi connect profile đã chọn. Có timeout và rollback.

### `Check-Installation.bat`

Chỉ đọc trạng thái cài đặt/config/network, không cố tình thay đổi WireSock settings.

## Backup và rollback

Trước khi sửa `wiresock.config`, Control Center tạo backup tại:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config.control-center-backup
```

Các standalone script có thể dùng tên backup riêng như:

```text
wiresock.config.toggle-backup
wiresock.config.profile-switch-backup
```

Các file backup này nằm trong `ProgramData`, không nằm trong repo.

## Recovery khi Internet bị block ngoài ý muốn

Nếu một connection lỗi và Internet vẫn bị block trong khi bạn **không chủ ý dùng Kill Switch**, mở Terminal/CMD bằng Administrator và thử:

```bat
wiresock-connect-cli disconnect
wiresock-connect-cli reset-network-lock
```

Sau đó connect lại một profile hoạt động:

```bat
wiresock-connect-cli connect "PROFILE_NAME" -exit
```

Nếu bạn cố ý bật Kill Switch, hãy hiểu rằng `reset-network-lock` sẽ gỡ network lock đó; đừng chạy nó chỉ vì thích bấm nút cho vui.

## Lưu ý

- Script thao tác trực tiếp với `wiresock.config`; nên giữ backup nếu bạn tự sửa code.
- Không commit `wiresock.config` cá nhân lên GitHub. File đó có thể chứa endpoint, đường dẫn ứng dụng và các setting riêng.
- Tên profile có thể khác hoàn toàn giữa các máy; script lấy danh sách trực tiếp từ WireSock CLI nên không hardcode profile cụ thể.
- `Check-Installation.bat` chỉ là diagnostic. Nó không phải trình sửa lỗi tự động.

## Quick start

Nếu máy chưa cài WireSock:

```text
1. standalone\Install-WireSock-and-Add-PATH.bat
2. mở terminal mới hoặc đăng xuất/đăng nhập lại nếu PATH chưa refresh ở app đang chạy
3. WireSock-Control-Center.bat
```

Nếu WireSock đã cài và CLI hoạt động:

```text
WireSock-Control-Center.bat
```

Thế là đủ. Một cửa sổ CMD nhỏ làm việc mà đáng lẽ GUI đã có thể expose bằng vài hotkey từ đầu, nhưng con người thích xây bảng điều khiển cho bảng điều khiển.
