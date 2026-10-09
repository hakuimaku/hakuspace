# Quản lý sao chép Dotfiles của HakuSpace

Tài liệu này giải thích cách HakuSpace cài đặt, cập nhật và rollback các file cấu hình người dùng. HakuSpace sử dụng **mô hình triển khai bằng cách sao chép**. Nó không sử dụng GNU Stow, symbolic link, Git worktree hay cơ chế đồng bộ trực tiếp.

Đây là tài liệu chi tiết bổ sung cho tài liệu [Kiến trúc HakuSpace](../architecture.md).

Repository là nguồn của các mặc định được quản lý bằng phiên bản. Thư mục home của người dùng chứa các bản sao độc lập của những mặc định đó, cùng với các file do người dùng sở hữu và trạng thái do ứng dụng tạo ra.

## 1. Mô hình cốt lõi

Repository lưu bố cục thư mục home nền trong `src/home/`:

```text
Repository                         Thư mục home của người dùng
-----------                        ----------------------------
src/home/.config/*       --copy--> ~/.config/*
src/home/.local/bin/*    --copy--> ~/.local/bin/*
src/home/.nanorc         --copy--> ~/.nanorc
src/home/hakuspace-control/*
                           --copy--> ~/hakuspace-control/*
```

File đã được sao chép có inode riêng và có thể được chỉnh sửa độc lập với nguồn trong repository. Chỉnh sửa file đã triển khai không chỉnh sửa Git checkout. Tương tự, chỉnh sửa file trong repository không thay đổi cấu hình desktop đang hoạt động cho đến khi một thao tác install hoặc update sao chép file đó lần nữa.

Mô hình này có hai khu vực sở hữu quan trọng:

- **Cấu hình nền**: các mặc định được quản lý bằng phiên bản trong `src/home/`. Repository duy trì các file này và một lần cài đặt hoặc cập nhật sau có thể thay thế chúng.
- **Cấu hình tùy chỉnh**: các thiết lập riêng của người dùng trong `~/hakuspace-control/`. Cấu hình nền được thiết kế để nạp hoặc tham chiếu đến thư mục này, nhờ đó các thiết lập cá nhân có thể tồn tại qua những thay đổi của cấu hình nền.

Đây là một ranh giới có chủ đích. Nên tùy chỉnh cấu hình trong `~/hakuspace-control/` khi file nền tương ứng hỗ trợ cơ chế override đó. Chỉnh sửa trực tiếp file nền đã triển khai trong `~/.config` hoặc `~/.local/bin` có thể bị ghi đè ở lần triển khai sau.

## 2. Thế nào là một đích được quản lý

Installer và updater triển khai một tập hợp đích đã được xác định. Chúng không sở hữu toàn bộ thư mục home.

### Các đích cấu hình

Các mục trong `src/home/.config/` được sao chép sang các mục tương ứng dưới `~/.config/`, với xử lý riêng cho các thư mục window manager:

- Các thư mục và file ứng dụng thông thường được sao chép sang đường dẫn tương ứng dưới `~/.config/`.
- `hypr/`, `niri/`, `mango/` và `labwc/` được triển khai qua các nhánh riêng vì window manager được chọn quyết định phần nào được sao chép.
- Hyprland có thể triển khai riêng `hypr/config`, `hyprland.lua`.
- `hypridle.conf`, `hyprlock.conf` và `hyprlock_tiny.conf` luôn được copy không phụ thuộc vào window manager, vì nó là các file cấu hình lõi cho `hypridle` và `hyprlock` (chúng nó có default location cho config file trùng với `~/.config/hypr/` của Hyprland nên cần xử lý đặc biệt).
- `gtk-3.0/gtk.css` được triển khai như một file cụ thể. Thư mục `gtk-3.0` hiện có sẽ được sao lưu bằng `backup_dir` trước khi file đó được sao chép.
- `starship.toml`, `mimeapps.list` và các file cấu hình cấp cao khác được sao chép vào đường dẫn tương ứng.

### Script cục bộ

`src/home/.local/bin/` được sao chép sang `~/.local/bin/`. Installer và updater sao chép nội dung thư mục, sau đó cấp quyền thực thi cho các script đã triển khai khi cần.

### Các file khác

Installer và updater cũng triển khai `src/home/.nanorc` sang `~/.nanorc`.

### Các file nằm ngoài ranh giới này

Các script không chủ động quản lý mọi file trong `~/.config` hoặc `~/.local`. Ví dụ, thư mục ứng dụng không nằm trong danh sách triển khai của repository vẫn thuộc quyền sở hữu của người dùng. Rollback cũng tuân theo ranh giới này: chỉ xóa các đích được quản lý và giữ lại các mục không liên quan.

## 3. Helper sao chép và sao lưu dùng chung

Hành vi dùng chung nằm trong `scripts/functions.sh`, còn các đường dẫn nằm trong `scripts/variables.sh`.

### `copy_file`

`copy_file SOURCE DESTINATION` thực hiện các bước sau:

1. Kiểm tra source là một file thông thường.
2. Nếu destination đã tồn tại và việc sao lưu không bị tắt, gọi `backup_item`.
3. Tạo thư mục cha của destination nếu cần.
4. Sao chép source lên destination bằng `cp -f`.
5. Ghi log thao tác sao chép.

Đối số thứ ba tùy chọn sẽ tắt việc tự động sao lưu của helper. Cách này được dùng khi caller đã sao lưu thư mục trước đó hoặc khi rollback đã xóa các đích được quản lý.

### `copy_dir_content`

`copy_dir_content SOURCE_DIR DESTINATION_DIR` thực hiện các bước sau:

1. Kiểm tra source directory tồn tại.
2. Nếu destination tồn tại và việc sao lưu không bị tắt, gọi `backup_item`.
3. Tạo destination directory nếu cần.
4. Sao chép nội dung source vào destination bằng `cp -rf SOURCE_DIR/. DESTINATION_DIR/`.
5. Ghi log thao tác sao chép.

Điểm quan trọng là đây là **hợp nhất nội dung sau khi sao lưu**, không phải thuật toán đồng bộ tại chỗ. Trong các thao tác install/update thông thường, destination hiện có được chuyển đi trước khi sao chép, nên thư mục đích bắt đầu ở trạng thái sạch. Trong rollback, các đích cũng được xóa rõ ràng trước khi khôi phục với cùng mục đích.

### `backup_item`

`backup_item TARGET` chuyển target hiện có vào thư mục sao lưu hiện tại và giữ nguyên đường dẫn tương đối so với `$HOME`:

```text
$HOME/.config/kitty
    -> $HOME/.backup/Backup_YYYY-MM-DD_HH-MM-SS/.config/kitty
```

Helper sử dụng `mv`, không phải `cp`, nên destination ban đầu bị xóa như một phần của thao tác sao lưu. Nếu cần quyền cao hơn, helper sử dụng `sudo` và cố gắng khôi phục quyền sở hữu của đường dẫn sao lưu cho user hiện tại.

### `backup_dir`

`backup_dir TARGET_DIRECTORY` tạo một bản sao lưu của thư mục thay vì chuyển thư mục đó đi. Cách này được dùng khi triển khai theme GTK cụ thể, trước khi thay thế `gtk-3.0/gtk.css`. Nó khác với `backup_item`, vốn thường chuyển destination ra khỏi vị trí cũ.

## 4. Lưu trữ bản sao lưu

Bản sao lưu được lưu bên dưới:

```text
~/.backup/
```

Một bản sao lưu thông thường của installer hoặc updater có dạng:

```text
~/.backup/Backup_YYYY-MM-DD_HH-MM-SS/
├── .config/
│   ├── application-name/
│   └── another-config
├── .local/
│   └── bin/
├── .nanorc
└── ...
```

Bản sao lưu chứa các đích đã được chuyển hoặc sao chép trước một thao tác triển khai. Vì vậy, nó là điểm khôi phục cho các file bị ảnh hưởng bởi lần chạy đó. Không nên xem nó là ảnh chụp toàn bộ thư mục home trừ khi thao tác đã sao lưu mọi đường dẫn liên quan.

Tên bản sao lưu có dấu thời gian để dễ sắp xếp. `rollback.sh` liệt kê chúng theo thứ tự từ điển đảo ngược, nhờ đó timestamp mới nhất đứng trước khi định dạng timestamp không thay đổi.

## 5. `install.sh`: triển khai lần đầu

`install.sh` là entry point thiết lập tổng quát. Ngoài triển khai cấu hình, nó có thể cài package, tạo thư mục, triển khai tài nguyên, khởi tạo `hakuspace-control` và thực hiện thiết lập hệ thống tùy chọn.

Luồng liên quan đến dotfiles là:

1. **Nạp đường dẫn và helper của repository** từ `scripts/variables.sh` và `scripts/functions.sh`.
2. **Chọn window manager**. Lựa chọn này quyết định danh sách package WM và nhánh cấu hình được dùng.
3. **Tạo các thư mục cần thiết**, bao gồm `~/.config`, thư mục theme và thư mục wallpaper.
4. **Triển khai các thư mục cấu hình chung** từ `src/home/.config/`, ngoại trừ các thư mục được xử lý bởi quy tắc chỉ chạy một lần hoặc quy tắc window manager.
5. **Triển khai các file và thư mục WM cụ thể** cho WM đã chọn.
6. **Triển khai các thư mục cấu hình chỉ cài một lần** như Thunar, XFCE, MPV và btop. Các thư mục này được khởi tạo một lần và được bảo vệ khỏi việc updater ghi đè về sau.
7. **Triển khai các file riêng lẻ**, bao gồm stylesheet GTK, cấu hình Starship, `.nanorc` và `mimeapps.list`.
8. **Triển khai các script cục bộ** từ `src/home/.local/bin/` sang `~/.local/bin/`.
9. **Chạy các bước thiết lập tiếp theo**, như khởi tạo `~/hakuspace-control` và các service hệ thống tùy chọn.

Với các đích thông thường, helper sao chép sẽ sao lưu target hiện có trước khi sao chép. Kết quả là một bản sao độc lập được triển khai trong thư mục home và một bản sao khôi phục trong `~/.backup/`.

Do đó, lần cài đặt đầu tiên có thể giữ lại các file đã tồn tại trước khi cài HakuSpace. Tuy nhiên, người dùng nên xem kỹ các prompt mà mình chấp nhận vì quá trình cài đặt còn thực hiện các thiết lập package và hệ thống ngoài việc triển khai dotfiles.

## 6. `update.sh`: cập nhật repository và cấu hình

`update.sh` cập nhật một bản cài HakuSpace hiện có. Trước tiên, script có thể thay đổi revision của repository, sau đó triển khai các file cấu hình mới hơn.

### Giai đoạn cập nhật repository

Người dùng có thể chọn:

- **Latest**: chuyển sang branch main và pull từ remote.
- **Stable**: fetch tag và checkout tag release mới nhất hiện có.
- **Skip**: giữ nguyên revision repository hiện tại.

Nếu updater tự thay đổi trong quá trình cập nhật repository, script sẽ chạy lại chính nó để phần còn lại sử dụng logic mới.

### Giai đoạn cập nhật cấu hình

Updater sau đó sẽ:

1. Chọn cấu hình window manager cần cập nhật.
2. Sao chép các thư mục cấu hình chung được quản lý.
3. Bỏ qua `ONCE_CONFIGS`, giữ lại các thay đổi cục bộ trong những thư mục đó sau lần cài đầu tiên.
4. Triển khai cấu hình WM đã chọn và các file WM dùng chung.
5. Sao lưu và triển khai stylesheet GTK.
6. Cập nhật `starship.toml` và `.nanorc`.
7. Sao chép các script cục bộ được quản lý sang `~/.local/bin/`.
8. Tùy chọn thực hiện cập nhật cấu hình NixOS và rebuild.

Một lần cập nhật thông thường có thể ghi đè các chỉnh sửa trực tiếp vào file nền được quản lý vì những file này được repository kiểm soát có chủ đích. Nên chuyển thiết lập tùy chỉnh sang `~/hakuspace-control` hoặc một vị trí do người dùng sở hữu được hỗ trợ trước khi cập nhật.

Mỗi lần cập nhật tạo một bản sao lưu có timestamp riêng trong `~/.backup/`. Nhờ đó, rollback sau này có thể chọn trạng thái tồn tại trước một lần cập nhật cụ thể.

## 7. `rollback.sh`: dọn dẹp và khôi phục có chọn lọc

Rollback không được triển khai như việc sao chép mù lên toàn bộ home hiện tại. Mục đích của nó là đưa các đích được quản lý về trạng thái được ghi trong bản sao lưu đã chọn, đồng thời tránh các file người dùng không liên quan.

### Giai đoạn chọn bản sao lưu

`rollback.sh`:

1. Nạp cùng các định nghĩa đường dẫn và helper được installer và updater sử dụng.
2. Tìm các thư mục khớp với `~/.backup/Backup_*`.
3. Sắp xếp chúng theo thứ tự mới nhất trước.
4. Tự động chọn bản sao lưu duy nhất nếu chỉ có một bản; nếu có nhiều bản thì hiển thị prompt.
5. Yêu cầu xác nhận trước khi thay đổi thư mục home.

### Giai đoạn xử lý các đích được quản lý

Sau khi xác nhận, rollback xây dựng danh sách các đích mà installer và updater có thể quản lý. Danh sách bao gồm các mục cấu hình trong repository, đường dẫn WM đặc biệt, `~/.local/bin` và `~/.nanorc`.

Mỗi đích hiện có được chuyển vào một thư mục an toàn mới:

```text
~/.backup/Rollback_Backup_YYYY-MM-DD_HH-MM-SS/
```

Đây là trạng thái tồn tại ngay trước rollback. Việc giữ lại trạng thái này giúp rollback có thể đảo ngược nếu bản sao lưu đã chọn không phải bản mong muốn.

Các mục không liên quan không được đưa vào danh sách. Ví dụ:

```text
~/.config/unrelated-app/
~/.local/share/
```

sẽ không bị xóa chỉ vì rollback đang chạy. Một thư mục cùng cấp dưới `~/.config` hoặc `~/.local` chỉ bị ảnh hưởng khi nó là một trong các đích được quản lý rõ ràng.

### Giai đoạn khôi phục

Rollback sau đó duyệt qua bản sao lưu đã chọn. Với `.config` và `.local`, script khôi phục các mục con trực tiếp vào `$HOME` để các thư mục chứa này không bị xóa hoặc thay thế. Các mục cấp cao khác trong bản sao lưu, chẳng hạn `.nanorc`, được khôi phục trực tiếp.

Bản sao lưu đã chọn được sao chép vào thư mục home với việc sao lưu bị tắt vì các đích được quản lý hiện tại đã được chuyển vào thư mục an toàn của rollback. Điều này tránh các thao tác sao lưu trùng lặp và giúp log dễ hiểu hơn.

### Hệ quả quan trọng

Một bản sao lưu đại diện cho trạng thái trước đó được ghi lại bởi một thao tác install hoặc update. Nếu một đích được quản lý không có trong bản sao lưu, rollback sẽ không tạo lại đích đó. Vì rollback xóa danh sách các đích được quản lý trước khi khôi phục, đích đó có thể tiếp tục không tồn tại sau thao tác. Đây là chủ ý: nó ngăn các file cũ tồn tại sau rollback, nhưng cũng có nghĩa là người dùng cần chọn bản sao lưu tương ứng với trạng thái triển khai mong muốn.

## 8. Vòng đời ví dụ

Giả sử hệ thống hiện có:

```text
~/.config/kitty/kitty.conf       # được quản lý
~/.config/my-unrelated-app/      # không liên quan
~/.local/bin/haku.sh             # được quản lý
```

Một lần cập nhật thay đổi `kitty.conf` và triển khai một script mới. Trước khi sao chép, các đích được quản lý cũ được lưu dưới một thư mục `Backup_*` có timestamp.

Nếu không muốn dùng bản cập nhật, rollback về mặt khái niệm sẽ làm như sau:

```text
1. Chọn ~/.backup/Backup_...
2. Chuyển các đích kitty và local/bin hiện tại vào ~/.backup/Rollback_Backup_...
3. Giữ nguyên ~/.config/my-unrelated-app/
4. Khôi phục các mục .config và .local từ bản sao lưu đã chọn
5. Khôi phục các file như .nanorc nếu có
```

Repository vẫn không thay đổi trong suốt quá trình. Rollback chỉ thay đổi các bản sao đã triển khai trong thư mục home của người dùng.

## 9. Quy tắc tùy chỉnh

Hãy tuân theo các quy tắc sau để tránh mất thiết lập cá nhân:

- Xem `src/home/` là input nền được quản lý bằng phiên bản, không phải thư mục cấu hình đang hoạt động.
- Đặt các override cá nhân được hỗ trợ trong `~/hakuspace-control`.
- Lường trước việc các chỉnh sửa trực tiếp vào file được quản lý trong `~/.config` và `~/.local/bin` sẽ bị thay thế bởi install hoặc update.
- Kiểm tra hành vi của `ONCE_CONFIGS`. Chúng được khởi tạo khi cài đặt nhưng bị bỏ qua trong các lần cập nhật thông thường.
- Giữ các bản sao lưu quan trọng trong `~/.backup/` cho đến khi xác minh xong lần cập nhật tương ứng.
- Không tự đổi tên thư mục sao lưu nếu bạn dựa vào việc sắp xếp theo timestamp.
- Sau khi khôi phục cấu hình WM, hãy reload window manager tương ứng hoặc khởi động lại các ứng dụng bị ảnh hưởng.

## 10. Ưu điểm và đánh đổi

### Ưu điểm

- Sử dụng các file thông thường và tool shell tiêu chuẩn.
- Không yêu cầu người dùng biết về symbolic link hoặc một dotfiles manager đặc biệt.
- Giữ các mặc định của repository portable và dễ kiểm tra.
- Tạo các điểm khôi phục có timestamp trước khi triển khai các đích được quản lý.
- Cho phép cấu hình người dùng không liên quan cùng tồn tại trong các thư mục home tương tự.
- Làm rõ ranh giới giữa nền và tùy chỉnh.

### Đánh đổi

- Sao chép tốn nhiều dung lượng đĩa hơn symbolic link.
- File đã triển khai có thể lệch khỏi file trong repository giữa các lần cập nhật.
- Chỉnh sửa trực tiếp vào file được quản lý có thể bị ghi đè.
- Thư mục sao lưu cần được dọn dẹp định kỳ và cần đủ dung lượng đĩa.
- Một bản sao lưu gắn với một thao tác cụ thể, không tự động là snapshot toàn bộ home.
- Quy tắc triển khai phải được giữ đồng bộ với danh sách đích được quản lý của rollback khi thêm đường dẫn được quản lý mới.

Nguyên tắc thiết kế trung tâm rất đơn giản: `src/home/` là nguồn cấu hình nền có thể tái lập, thư mục home chứa các bản sao đã triển khai, `~/hakuspace-control` chứa tùy chỉnh do người dùng sở hữu, và `~/.backup/` cung cấp các điểm khôi phục quanh các thao tác sao chép.
