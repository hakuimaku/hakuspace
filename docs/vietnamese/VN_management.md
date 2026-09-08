# Quản lý dotfiles của tôi làm sao?

Xem bản tiếng Anh [Management](../management.md).

Đây là tài liệu bổ sung cho [Architecture](VN_architecture.md) để giải thích cách dotfiles được triển khai và quản lý trong thư mục home của bạn một cách an toàn nhất.

Repository là nguồn của các cấu hình mặc định được quản lý bằng phiên bản. Thư mục home của bạn chứa các bản sao độc lập, cùng với những file riêng và dữ liệu do ứng dụng tạo ra.

## 1. Mô hình cốt lõi

Repository lưu bố cục BASE config trong `src/home/`:

```text
Repository                         Thư mục home của bạn
-----------                        ----------------------------
src/home/.config/*       --copy--> ~/.config/*
src/home/.local/bin/*    --copy--> ~/.local/bin/*

src/home/hakucfg/*       --copy--> ~/hakucfg/*
```

Mọi file cấu hình trong home của bạn là của bạn, bạn có thể tuỳ ý sửa nó mà không làm thay đổi repository. Đây là điều tôi rất thích của cơ chế copy config thay vì symbolic link, bạn không cần hiểu rõ về git và không lo bị conflict khi pull repository để cập nhật dotfiles. Nhưng là 1 user, bạn muốn phải có nhiều tuỳ biến hơn, vì vậy tôi đã tạo ra một thư mục `~/hakucfg/` để bạn đặt các file cấu hình cá nhân.

- **BASE**: tất cả nhũng file cấu hình, script có trong hakuspace, đây là những file được thay đổi bởi tôi, bạn có thể tuỳ biến chúng nhưng sẽ bị ghi đè khi update. Giải pháp là một thư mục cấu hình cá nhân của chính bạn, tôi đặt nó là `~/hakucfg/`.
- **CUSTOM**: các thiết lập riêng của bạn trong `~/hakucfg/`. Cấu hình độc nhất của bạn, sẽ không thể bị ghi đè, được `install.sh` và `update.sh` triển khai để pull mới về các config bị thiếu đảm bảo bạn có thể dùng nó ngay.

Cho nên, đừng sửa trực tiếp các file trong `~/.config` (của hakuspace) hoặc `~/.local/bin` nếu bạn muốn giữ chúng qua các lần cập nhật. Thay vào đó, hãy sửa đổi trong `~/hakucfg/`, tôi đang cố gắng giúp bạn tuỳ biến nhiều nhất có thể khi dùng dotfiles của tôi.

## 2. Cách triển khai và quản lý

Ba script có vai trò khác nhau:

- `install.sh` là luồng cài đặt ban đầu: chọn window manager, cài package, tạo thư mục cần thiết, triển khai cấu hình, script trong `~/.local/bin`, asset tùy chọn và các thiết lập hệ thống.
- `update.sh` cập nhật repository trước khi triển khai. Có thể chọn `LATEST` để pull nhánh `main`, `STABLE` để checkout tag mới nhất, hoặc `SKIP` để giữ nguyên repository hiện tại. Sau đó script cập nhật package, cấu hình và `~/.local/bin` theo lựa chọn của người dùng.
- `rollback.sh` không cài lại package hay chạy lại cài đặt hệ thống; nó chỉ khôi phục những file và thư mục dotfile được HakuSpace quản lý từ một backup đã chọn.

### Cấu hình 1 lần ONCE_CONFIGS

- Đây là các cấu hình chỉ được triển khai một lần trong lần cài đặt đầu tiên.
- Giúp 1 số cấu hình tôi không thay đổi thường xuyên và các cấu hình này cần được thay đổi tuỳ nhu cầu của bạn giữ lại sau mỗi khi chạy `update.sh` hoặc `rollback.sh`.
- Lưu ý: chạy `install.sh` sẽ triển khai lại các cấu hình này nên tôi mới không khuyên chạy `install.sh` nhiều lần, chỉ chạy 1 lần đầu tiên là đủ.
- Bao gồm: 
  - `~/.config/Thunar`
  - `~/.config/xfce4`
  - `~/.config/mpv`
  - `~/.config/btop`

> Bao gồm cả mimeapps.list

### Triển khai cấu hình chung

Đây là các file và thư mục trong `src/home/.config` không thuộc `ONCE_CONFIGS`, `SKIP_CONFIGS` hoặc luồng xử lý riêng. Khi người dùng xác nhận triển khai:

- `install.sh` và `update.sh` copy nội dung cấu hình nền vào `~/.config`.
- Nếu đích đã tồn tại, script backup mục hiện tại trước rồi mới copy cấu hình mới.
- `update.sh` không tự cập nhật nếu người dùng bỏ qua bước cập nhật config.
- Các cấu hình chung được quản lý theo từng thư mục hoặc file; file riêng của người dùng nằm ngoài danh sách nguồn sẽ không bị script xoá.

Ngoài `~/.config`, hai script còn xử lý `src/home/.local/bin` vào `~/.local/bin`. Các script sau khi copy được cấp quyền thực thi. Đây là phần cập nhật trực tiếp từ BASE, vì vậy không nên sửa bản đã triển khai nếu muốn giữ thay đổi qua lần update.

### Triển khai cấu hình cần xử lý đặc biệt

Một số cấu hình không đi qua vòng lặp cấu hình chung:

- **Window manager**: người dùng chọn Hyprland, Niri, Mango hoặc Labwc (hoặc tất cả). `install.sh` và `update.sh` chỉ triển khai WM đã chọn. Hyprland copy `config/` vào `~/.config/hypr/config` và copy riêng `hyprland.lua`; các WM còn lại copy vào thư mục tương ứng.
- **Các file Hyprland dùng chung**: `hypridle.conf`, `hyprlock.conf` và `hyprlock_tiny.conf` được copy riêng vào `~/.config/hypr`, được dùng chung bởi tất cả WM thay vì chỉ Hyprland, phải xử lý đặt biệt vì chúng có đường dẫn mặc định trong `~/.config/hypr`. Nếu tôi cứ thể copy chúng thì 1 là config hyprland mất hết và 2 là nếu bạn dùng WM khác mà có các file cấu hình cho hyprland thì bạn sẽ nghĩ nó là bloat nên tôi đơn giản là không muốn:)
- **GTK**: `gtk-3.0/gtk.css` được copy riêng, đây là file theme cho gtk3 app và file manager Thunar. Được xử lý đặc biệt bởi vì tôi không muốn bạn bị mất bookmark trong file manager.
- **Các file đơn**: `starship.toml`, `.nanorc` được copy thủ công vào `~/.config` và `~/.nanorc`. Vì chỉ copy_file mới có thể giải quyết chúng.
- **`mimeapps.list`**: chỉ được triển khai trong `install.sh`, không được `update.sh` ghi đè (là 1 dạng ONCE_CONFIGS nhưng nó là file nên tôi không để nó vào danh sách ONCE_CONFIGS).
- **`~/hakucfg`**: cuối `install.sh` và `update.sh`, `check_control_dir` tạo thư mục cùng các file custom còn thiếu từ `src/home/hakucfg`. `setting.sh` chỉ được cập nhật khi phiên bản khác nhau và người dùng đồng ý; việc này có thể ghi đè tùy chỉnh trong file đó. Các file custom hiện có khác không bị thay thế tự động.
- **NixOS và dịch vụ hệ thống**: `install.sh` có thể triển khai cấu hình NixOS, đổi shell mặc định sang fish, bật dịch vụ `ly` và đặt Thunar làm file manager mặc định. `update.sh` có thể cập nhật/rebuild NixOS. Đây là thay đổi cấp hệ thống, không phải bản copy dotfile thông thường.

## 3. Lưu trữ bản sao lưu

Các script lưu backup trong `~/.backup/` theo dạng:

```text
~/.backup/Backup_<YYYY-MM-DD_HH-MM-SS>/
~/.backup/Rollback_Backup_<YYYY-MM-DD_HH-MM-SS>/
```

### Khi install hoặc update

- Mỗi lần chạy script tạo một `Backup_<timestamp>` dùng chung cho lần chạy đó.
- Trước khi copy đè một file hoặc thư mục đã tồn tại, `backup_item` chuyển mục hiện tại vào backup và giữ nguyên cấu trúc tương đối từ thư mục home. Vì vậy backup có thể chứa `.config/...`, `.local/bin/...` hoặc `.nanorc`.
- Backup được tạo trước khi thay đổi, nên có thể dùng `rollback.sh` để chọn một backup cũ và khôi phục.

### Khi rollback

- `rollback.sh` chỉ hiển thị các thư mục có tên bắt đầu bằng `Backup_`, sắp xếp backup mới nhất trước. Nó không sử dụng các thư mục không do HakuSpace tạo.
- Trước khi khôi phục, các file và thư mục đang được HakuSpace quản lý sẽ được chuyển sang `Rollback_Backup_<timestamp>`. Đây là bản backup an toàn của trạng thái trước rollback; script hiện không đưa nhóm `Rollback_Backup_*` vào danh sách lựa chọn tự động.
- Script chỉ khôi phục các đường dẫn managed như cấu hình chung, cấu hình WM đã biết, `~/.local/bin` và `~/.nanorc`. Các file không nằm trong danh sách này được giữ nguyên.
- Khi khôi phục `.config` hoặc `.local`, script xử lý từng mục managed thay vì copy nguyên cả thư mục; các cấu hình ONCE luôn bị bỏ qua.
- Rollback không khôi phục package, asset, shell, dịch vụ hệ thống hoặc cấu hình NixOS. Những thay đổi đó cần được xử lý riêng.

Không nên xoá backup ngay sau khi update hoặc rollback. Hãy kiểm tra cấu hình và ứng dụng trước; khi đã chắc chắn trạng thái mới hoạt động, các backup cũ mới có thể được dọn thủ công để giải phóng dung lượng.

## 4. Kết luận

Nguyên tắc thiết kế trung tâm rất đơn giản: `src/home/` là nguồn cấu hình BASE có thể tái lập, thư mục home chứa các bản sao đã triển khai, `~/hakucfg` chứa tùy chỉnh do người dùng sở hữu - là CUSTOM, và `~/.backup/` cung cấp các điểm khôi phục quanh các thao tác sao chép.
