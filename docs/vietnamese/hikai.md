# Hikai

Tài liệu này mô tả kiến trúc và các nguyên tắc tổ chức của Hikai.
Tài liệu không cố liệt kê đầy đủ từng tính năng, thiết lập, token hay giá trị mặc định đang có.
Hãy xem code hiện tại để biết chính xác những chi tiết đó.

[English](../hikai.md)

## Hikai là gì

Hikai là chế độ shell của HakuSpace dựa trên Quickshell. Classic là một chế độ shell khác.
Hikai là một shell có state, service, surface và phần tích hợp dùng chung, thay vì một tập hợp các widget độc lập.

## Cách đọc tài liệu này

Đọc mô hình tư duy và nguyên tắc ownership trước. Dùng các phần còn lại khi làm việc với ranh giới tương ứng.
Đây là hướng dẫn tổ chức thay đổi, không phải khẳng định rằng mọi chỗ trong code đều đã tuân thủ hoàn toàn.

Bắt đầu lần theo hành vi runtime từ [source của shell](../../src/home/.config/quickshell/hakuspace/).
Theo owner của hành vi đó đến các nơi gọi và test trước khi sửa.
Tra tên, schema, giá trị mặc định và thao tác được hỗ trợ trong code, thay vì suy ra từ tài liệu này.

## Mô hình tư duy

Có thể nhìn một tương tác thông thường như một vòng lặp:

```text
sự kiện bên ngoài
    -> service/backend
    -> state chung
    -> lớp hiển thị
    -> thao tác người dùng
    -> action/backend chung
    -> cập nhật state đã được xác nhận
```

Service runtime theo dõi hệ thống bên ngoài. State chung giúp các nơi hiểu những dữ liệu đó theo cùng một cách.
Lớp hiển thị đọc state và chuyển input thành yêu cầu.
Lớp trừu tượng window manager chuyển đổi hành vi compositor, phần tích hợp hệ thống thực hiện thao tác nghiệp vụ, còn cấu hình lưu bền giữ lựa chọn người dùng qua các phiên.

Một surface có thể biến mất trong khi service của nó vẫn hoạt động. Hiển thị cùng dữ liệu trên output khác nên dùng lại owner đó, không tạo thêm nguồn dữ liệu độc lập.

## Kiến trúc runtime

Quickshell kết hợp runtime của shell, các service chung và các surface gắn với output.
Vòng đời phiên quản lý khởi động, dừng và phục hồi; component UI không nên tự khởi động thêm một runtime shell.
Reload cũng là một lần chuyển vòng đời. Khởi tạo và dọn dẹp phải chịu được reload mà không tạo trùng process, subscription hay bên sở hữu protocol.

Đặt model và phần điều phối chung trong [services](../../src/home/.config/quickshell/hakuspace/services/), còn phần hiển thị và hành vi UI tái sử dụng trong [components](../../src/home/.config/quickshell/hakuspace/components/).
Thao tác hệ thống nên đi qua service thích hợp hoặc [backend không có UI](../../src/core/backend/).
[Kiến trúc core script](../../src/core/README.md) giải thích cách định tuyến lệnh công khai và triển khai.

Đưa việc chậm và IO bên ngoài ra khỏi binding dùng để render. Ưu tiên sự kiện thay cho polling lặp lại khi hệ thống có hỗ trợ.
Dùng chung tác vụ tốn tài nguyên và giải phóng subscription hoặc process khi không còn nơi nào cần chúng.

## State và ownership

Mỗi state nên có một nơi chịu trách nhiệm chính, gọi là owner. Owner định nghĩa ý nghĩa, nhận yêu cầu thay đổi và quyết định khi nào state hợp lệ.
Component khác đọc state đó hoặc yêu cầu một action. Hai surface hiển thị cùng giá trị không nên tự giữ hai bản có quyền quyết định riêng.

Tách state của protocol và backend khỏi state hiển thị. Service chịu trách nhiệm về dữ liệu hệ thống bên ngoài báo về và việc yêu cầu đã thành công hay chưa.
Surface giữ các chi tiết cục bộ như hover, nội dung tìm kiếm hay vị trí điều hướng khi chúng không cần phối hợp với nơi khác.
Ẩn surface không được vô tình dừng service chung hoặc xóa dữ liệu của nó.

State tương tác cần nhiều surface thống nhất nên thuộc một nơi điều phối chung.
Nơi này quyết định surface tạm nào sở hữu tương tác, nguồn kích hoạt và output của nó.
Host hiển thị chịu trách nhiệm về vị trí và hành vi cửa sổ. Nội dung chung giữ action và điều hướng chung, để thêm cách hiển thị không dẫn đến viết lại tính năng.

Tách state được yêu cầu khỏi state có hiệu lực. Lựa chọn đã lưu có thể tạm bị vô hiệu bởi bố cục đang dùng hoặc khả năng chưa có.
Suy ra kết quả có hiệu lực ở một nơi. Đừng xóa preference chỉ vì lúc này nó chưa áp dụng được.
Các nơi đọc state không nên tự tính lại cùng một quy tắc về khả năng sử dụng hay bố cục.

State lưu bền và state UI tạm có vòng đời khác nhau. Lưu lựa chọn có chủ đích và dữ liệu người dùng cần giữ qua phiên.
Gắn quyền sở hữu pointer, anchor đã chụp và tiến độ animation với tương tác tạo ra chúng.
Đừng lưu một chi tiết tạm xuống đĩa chỉ để component khác đọc được.

Với dữ liệu có thể sửa, phân biệt bản đã lưu, draft hiện tại, preview trực tiếp và thao tác đang chờ.
Chúng có vai trò khác nhau với owner rõ ràng, không phải những bản sao cạnh tranh làm nguồn chuẩn.
Suy ra trạng thái chưa lưu từ draft và bản đã xác nhận. Preview không có nghĩa là lưu thành công, và reset draft không đồng nghĩa với cho phép ghi đè dữ liệu trên đĩa.

Kết quả bất đồng bộ phải còn thuộc đúng yêu cầu, draft hoặc object đã tạo ra nó.
Phản hồi cũ không được ghi đè chỉnh sửa mới, tác động sang surface thay thế hoặc truy cập nội dung đã bị hủy.
Giữ draft khi lưu thất bại để người dùng sửa tiếp. Nếu nhiều lần lưu hoàn tất riêng lẻ, báo đúng phần thành công và giữ lại phần chưa lưu.

Ownership bao gồm cả dọn dẹp. Trả focus, vùng input, quyền giữ surface hiển thị và subscription khi owner đóng, chuyển giao hoặc biến mất.
Đóng về mặt logic có thể xảy ra trước khi animation đóng kết thúc. Chỉ giữ state hình ảnh cần thiết để chạy nốt animation, không để control ẩn tiếp tục nhận input.
Mở lại phải được ưu tiên hơn callback đóng cũ.

## Các loại surface của shell

Chọn loại surface theo cách nó tương tác:

| Loại | Trách nhiệm chính |
| --- | --- |
| Chrome thường trực của shell | Là một phần của bố cục desktop và sở hữu vùng dành riêng trong work area nếu cần. |
| Popup tạm | Hiện nội dung ngắn hạn gần nguồn gọi, có quy tắc đóng rõ ràng. |
| Panel | Chứa một tác vụ kéo dài, với vị trí, focus và cách đóng được xác định. |
| Overlay | Hiện nội dung phía trên các cửa sổ khác; phải quyết định rõ có modal hay không. |
| Menu | Đưa ra action và lựa chọn gắn với ngữ cảnh gọi. |
| OSD | Báo thao tác hoặc thay đổi state mà không lấy input hay focus không liên quan. |

Với mỗi surface, xác định owner, output, anchor, vùng input, chính sách focus và vòng đời.
Layer hình ảnh không tự động có quyền nhận input. Vùng trong suốt nên cho input đi xuyên qua, trừ khi tương tác chủ động cần giữ nó.
Overlay không tự trở thành modal chỉ vì cửa sổ phủ cả output.

Phân biệt vị trí cửa sổ, hình vẽ, vùng tương tác và phần desktop được dành riêng.
Nếu dùng các cửa sổ riêng để vẽ và nhận input cho cùng một surface, cả hai phải lấy từ cùng geometry và state chuyển tiếp.
Chỉ dành không gian một lần cho mỗi phần đóng góp vào bố cục; đừng suy ra nó từ hình dạng animation ở thời điểm hiện tại.

## Tích hợp window manager

Component UI nên đọc model chung hoặc gọi action chung, thay vì tự hiểu protocol của từng compositor.
Đặt việc nhận diện compositor, chuyển đổi sự kiện và lệnh native sau lớp trừu tượng window manager hoặc backend phù hợp.

Chuẩn hóa các khái niệm chung khi ý nghĩa của chúng tương đồng. Thể hiện rõ khác biệt về khả năng và dữ liệu không có, thay vì bịa giá trị hoặc giả định compositor nào cũng giống nhau.
Phân biệt state toàn cục, state theo output, active và focused khi compositor có sự phân biệt đó.
Lọc theo output và chọn đích cho action phải nằm trong contract này, không để từng surface tự đoán.

## Cấu hình và lưu bền

Cho phép cấu hình khi đó là lựa chọn hữu ích của người dùng. Giữ các quy tắc cố định của kiến trúc trong code.
Lưu preference và dữ liệu người dùng tạo; để khả năng sử dụng, hover, focus và tác vụ đang chạy ở runtime.
Dữ liệu theme được sinh ra, thiết lập đã lưu và cache có owner khác nhau, không nên âm thầm ghi đè lẫn nhau.

UI đọc và sửa thiết lập qua store chung. Store quản lý draft, preview và trạng thái thao tác; backend quản lý kiểm tra dữ liệu lưu trữ và ghi file.
Validation ở UI giúp người dùng, nhưng backend vẫn phải kiểm tra dữ liệu từ mọi nơi gọi.
Kiểm tra kiểu, giá trị cho phép, đường dẫn và revision của file khi dữ liệu đi qua ranh giới tin cậy.
Ghi an toàn và giữ nội dung, quyền truy cập không liên quan của người dùng. Khi đọc dữ liệu lỗi, báo lỗi thay vì thay dữ liệu hợp lệ bằng kết quả rỗng.

Migration thuộc ranh giới lưu trữ, không thuộc từng nơi dùng UI.
Giữ lựa chọn rõ ràng của người dùng, bảo đảm chạy lại an toàn và có thể phục hồi khi bị gián đoạn.
Chạy migration bắt buộc trước khi các phần runtime phụ thuộc bắt đầu đọc; một lần đọc thông thường không nên âm thầm ghi lại file người dùng.
Tra tên option, schema và giá trị mặc định hiện tại trong [backend thiết lập](../../src/core/backend/user/) và các store chung tương ứng.

### Settings và cá nhân hóa

Settings dùng một rail danh mục. Search mở đúng danh mục và đánh dấu thiết lập tìm được, đồng thời giữ ngữ cảnh của trang. Mọi tùy chọn luôn hiện trong đúng danh mục, kể cả mục Classic và WM không hoạt động; không còn công tắc Advanced. Search tìm được cả tên biến nhưng các dòng thiết lập chỉ hiện nhãn dễ đọc, ẩn tên biến và metadata phiên bản. Store giữ draft và định dạng lưu cũ.

General có font family và font size. Danh sách font có tìm kiếm, chỉ liệt kê font monospace đã cài từ cùng nguồn với Change Theme và đọc lại mỗi khi mở. Apply lưu font qua theme controller hiện có và cập nhật shell; Reload và Discard khôi phục giá trị đã lưu. Screenshot folder chỉ hiện ghi chú với Niri vì phím chụp màn hình tích hợp dùng cấu hình riêng của Niri.

Layer Change Theme native có font family, font size và màu accent; tùy chọn animation chỉ hiện khi dùng Niri. Các picker Rofi và Waybar nằm ở frontend Classic. Các trang theme dùng chung nền ink, khoảng cách, cỡ chữ và pill chọn có chuyển động của shell; đổi font native gọi trực tiếp theme controller.

Appearance và Desktop dùng chung preference của shell. Thư mục, chu kỳ đổi và transition Classic của wallpaper dùng preference chung; chất lượng video, phát và chuẩn bị video dùng preference wallpaper. Apply lưu store tương ứng; Apply & Close lưu tất cả store đã sửa. Configuration luôn liệt kê mọi file cấu hình WM và ưu tiên WM đang chạy. Tùy chọn recorder nằm trong Recording, font widget Classic và theme Waybar riêng trong Appearance, tùy chọn thoát phiên trong Session. Không còn tab Advanced hay Shortcuts riêng.

Picker wallpaper dùng chất lượng video đã lưu: chọn hình hoặc video rồi Apply. Việc chuẩn bị video theo chính sách đã chọn. Công cụ quản lý video cache và tùy chọn browser luôn hiện trong Wallpaper settings. Chọn avatar sẽ mở khung crop vuông có kéo và zoom trước khi lưu PNG 512×512; Cancel hoặc lỗi capture giữ avatar cũ.

Hộp thoại chọn thư mục và ảnh native tạm nhả quyền bàn phím và hạ layer gọi xuống dưới cửa sổ ứng dụng. Khi đóng hộp thoại, chỉ khôi phục owner nếu surface đó còn đang mở. Temp Note được ghim có thể vẫn hiện nhưng chia sẻ một owner bàn phím với Settings và Navigation; bấm phần note còn nhìn thấy sẽ chuyển input một cách rõ ràng.

## Phong cách và chuyển động

Dùng ngôn ngữ hình ảnh chung, giá trị từ theme và primitive tái sử dụng.
Tìm control hoặc primitive chuyển động sẵn có trước khi thêm style riêng.
Dùng lại hành vi chung nhưng giữ hình dạng phù hợp với mục đích của surface.
Các trạng thái focus, chọn, hover và disabled phải dễ phân biệt qua các theme và cách nhập.

Geometry cần một owner cho cạnh gắn, giới hạn an toàn và chuyển đổi tọa độ trên mỗi output.
Các nơi dùng nên hỏi theo những ý nghĩa đó, thay vì copy offset từ component khác.
Tách tính hình dạng, render, bố cục nội dung và chuyển động khi chúng có trách nhiệm khác nhau.

Chuyển động nên thể hiện thay đổi state và giữ sự liên tục khi bị ngắt hoặc đảo chiều.
Phản hồi của control thông thường nên nằm trong vùng bố cục ổn định. Chuyển tiếp surface có chủ đích có thể đổi geometry, nhưng input và focus phải theo trạng thái tương tác thực tế.
Đổi hướng gắn không được làm lật nội dung hoặc lệch vùng nhận input.
Xem code hiện tại để biết token hình ảnh và cấu hình chuyển động, không chép giá trị vào tài liệu.

## Input, focus và nhiều màn hình

Quyền xử lý bàn phím và pointer cần có owner rõ ràng. Focus cửa sổ được khôi phục không có nghĩa là vừa có thao tác bàn phím mới.
Chỉ giữ những phím tương tác cần dùng, và bảo toàn thao tác sửa văn bản cùng cách kích hoạt control thông thường.
Luôn có đường dùng bàn phím và chỉ dấu focus bên cạnh hành vi pointer.
Hủy xác nhận đang mở ở lớp trong cùng trước khi đóng lớp cha; không làm mất phần chưa lưu khi đóng.

Xác định lúc surface sẵn sàng nhận input và lúc đóng trả lại quyền đó.
Handoff pointer giữa trigger và nội dung nên dùng hành vi safe zone chung, suy ra từ vùng thực tế, gồm cả hành lang di chuyển.
Đừng thêm timer không liên quan hay vùng chặn input toàn output để che lỗi ownership.

Danh tính output và hệ tọa độ là một phần của mỗi yêu cầu đặt vị trí.
Phân biệt anchor theo màn hình, điểm theo cửa sổ và pixel vật lý; chuyển đổi chúng qua geometry chung.
Dùng anchor nguồn thật khi có, và xác định quy tắc chọn output cho lời gọi không có anchor.

Preference dùng chung không có nghĩa là dùng chung vị trí. Chuyển tương tác giữa các output phải trả focus, anchor và quyền giữ hiển thị của owner cũ.
Xử lý việc gỡ output, đổi scale và đổi bố cục mà không để surface còn sót, vùng dành riêng cũ hay subscription bị trùng.

## IPC và tích hợp bên ngoài

IPC và lệnh công khai là lối vào các action chung, không phải một cách triển khai riêng của chúng.
Giữ thao tác nghiệp vụ không phụ thuộc UI để surface của shell và nơi gọi bên ngoài dùng cùng hành vi đã được kiểm tra.
Dùng thao tác rõ ràng và ID ổn định, thay vì diễn giải nhãn hiển thị thành lệnh.

Kiểm tra yêu cầu ở ranh giới nhận vào, gồm output và khả năng sử dụng nguồn gọi khi có liên quan.
Tách action được yêu cầu khỏi kết quả đã xác nhận, truyền lỗi về và xác định cách hủy hoặc dọn dẹp yêu cầu đang chờ phản hồi.
Giữ tương thích với nơi gọi cũ khi đổi interface, hoặc cập nhật toàn bộ nơi gọi bị ảnh hưởng cùng phần kiểm chứng.
Tra điểm vào runtime và source backend để biết target IPC cùng tham số hiện tại.

## Thêm hoặc đổi một tính năng

1. Xác định owner và vòng đời của hành vi.
2. Xác định state chuẩn, state suy ra và state UI cục bộ.
3. Đặt IO bên ngoài và thao tác thay đổi dữ liệu sau ranh giới service hoặc backend.
4. Chọn loại hiển thị và dùng lại nội dung hoặc action chung.
5. Xác định focus, vùng input, nguồn kích hoạt, anchor và quy tắc output.
6. Chỉ nối lưu bền cho dữ liệu cần giữ qua phiên; thêm validation và migration khi cần.
7. Dùng lại primitive hình ảnh, geometry và chuyển động.
8. Kiểm chứng contract, nhánh lỗi và nơi gọi bị ảnh hưởng, gồm output khác và Classic khi sửa code dùng chung.

Lần theo đường hiện có trước khi thêm một đường song song.
Thay đổi hiển thị phải giữ an toàn dữ liệu và ý nghĩa backend, trừ khi tác vụ yêu cầu đổi chúng.
Chỉ thêm tài liệu khi tính năng đưa vào một khái niệm kiến trúc lâu dài hoặc đổi contract hiện có.

## Kiểm thử và gỡ lỗi

Kiểm thử ở ranh giới đang thay đổi. Dùng test thuần cho geometry và quy tắc model, test backend cho validation và lưu trữ, test runtime cho vòng đời QML và input thực tế.
Kiểm tra cú pháp không chứng minh hành vi. Khởi động mới không chứng minh live reload, và gán thẳng state không chứng minh đường đi của bàn phím hay pointer.

Tìm runner theo component và fixture trong [tests](../../tests/); công cụ check, probe và profiling nằm trong [tools](../../tools/).
[Script kiểm tra repo](../../tools/checks/repo_check.sh) định nghĩa các bước kiểm tra tổng hợp; đọc yêu cầu và tác động của runner trước khi chạy test compositor.
Dùng dữ liệu tạm, phiên cô lập và fixture action vô hại để kiểm thử không sửa preference thật hoặc tác động lên ứng dụng người dùng.

Kiểm tra hủy, đảo chiều nhanh, phản hồi cũ, ghi thất bại, nguồn biến mất và chuyển ownership.
Khi đổi vị trí hoặc input, kiểm tra thêm bố cục chật, nhiều output, scale, fullscreen và work area thực của client khi có liên quan.
Kết quả headless hoặc nested chỉ nói về môi trường đó; chúng không chứng minh đã đạt trên phần cứng thật.

Gỡ lỗi theo vòng sự kiện: xác nhận sự kiện bên ngoài, cập nhật service, state chung, hiển thị và kết quả action.
Đọc log runtime và supervisor để tìm lỗi load, binding, type và vòng đời trước khi chỉnh hình ảnh.
So sánh geometry với vùng input khi hình nhìn đúng nhưng tương tác lỗi.
Giữ probe và ảnh chụp tạm ngoài source chạy thật, ghi lệnh, bằng chứng và phần chưa kiểm tra trong issue hoặc PR.

## Hikai và Classic

Hikai và Classic cung cấp các cách hiển thị khác nhau cho thao tác HakuSpace dùng chung.
Facade công khai định tuyến yêu cầu theo chế độ đã chọn; backend không nên phụ thuộc vào cách hiển thị nào.
Giữ state UI của Hikai và preference UI của Classic tách biệt, trừ khi dữ liệu chung là chủ đích của contract.

Đổi chế độ phải giữ lựa chọn người dùng, trả tài nguyên của runtime cũ và tránh nhiều bên tranh quyền sở hữu service desktop.
Giữ đường phục hồi khi Hikai không khởi động được. Kiểm chứng lệnh chung ở cả hai chế độ khi đổi định tuyến hoặc ý nghĩa backend.

## Quy tắc viết tài liệu

Giữ bản [tiếng Anh](../hikai.md) và [tiếng Việt](hikai.md) cùng thứ tự section và ý nghĩa.
Dùng câu ngắn, đoạn ngắn và ngôn ngữ đời thường. Chỉ dùng dấu gạch ASCII, không dùng Unicode en dash hay em dash.

Không thêm danh sách hoặc ma trận tính năng hiện tại, danh sách thiết lập hay token, giá trị mặc định, kích thước, giá trị animation hoặc timeout cụ thể.
Không thêm trạng thái triển khai tạm, roadmap, báo cáo milestone, kết quả test gắn ngày, báo cáo runtime theo phiên bản hay ghi chú tương thích tạm thời.
Những chi tiết này thuộc code, issue, PR hoặc commit. Git history giữ lịch sử phát triển; không tạo kho lưu trữ tài liệu cho chúng.

Thêm section mới khi có một khái niệm kiến trúc mới thực sự.
Sửa section cũ khi contract hoặc mô hình tư duy của nó thay đổi, và giữ link đúng khi source di chuyển.
Thêm, đổi tên hoặc redesign tính năng không nên buộc phải viết lại danh sách tính năng ở đây.

## Chế độ màu Hikai

Appearance có Dark và Light, hỗ trợ preview, Apply và Discard. Ba mức surface sáng
là Pure White, White và Gray White; key `surfaceTone` vẫn là `ink`, `dark`, `soft`.
Schema v7 lưu `appearance.colorMode` trong `~/hakucfg/hikai/hikai-shell.json`;
preference cũ mặc định Dark và giữ nguyên các lựa chọn khác.

Mỗi seed accent thủ công hoặc lấy từ wallpaper sinh đồng thời một màu cho nền tối
và một màu cho nền sáng, bảo đảm contrast. `Theme.qml` chọn màu từ `quickshell.json`
mà không sinh lại theme hoặc chạy ColorThief khi đổi mode. Classic và ứng dụng dùng
chung luôn nhận accent cho nền tối. Chuyển sang Classic giữ preference Light của
Hikai; quay lại Hikai tự khôi phục Light.

Opaque chỉ có hiệu lực trong Classic. Request vẫn được lưu khi vào Hikai, nhưng các
override được xóa, bao gồm opacity của Kitty ở cả ứng dụng lẫn compositor. Transition
đồng bộ context dưới cover và khôi phục đúng context khi rollback. Xem [theme contracts](../core/theme.md).
