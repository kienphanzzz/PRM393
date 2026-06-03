import 'package:flutter/material.dart';

void main() {
  runApp(const BookReaderApp());
}

class BookReaderApp extends StatelessWidget {
  const BookReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusFlow Book Reader',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF2DD4BF),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          centerTitle: true,
        ),
      ),
      home: const BookLibraryScreen(),
    );
  }
}


class Book {
  final String id;
  final String title;
  final String author;
  final List<String> chapters;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.chapters,
  });
}


final List<Book> sampleBooks = [
  Book(
    id: '1',
    title: 'Đắc Nhân Tâm',
    author: 'Dale Carnegie',
    chapters: [
      'Chương 1: Muốn lấy mật thì đừng phá tổ ong',
      'Chương 2: Bí mật lớn nhất trong giao tiếp',
      'Chương 3: Ai làm được điều này sẽ có cả thế giới',
      'Chương 4: Thành thật quan tâm đến người khác',
    ],
  ),
  Book(
    id: '2',
    title: 'Nhà Giả Kim',
    author: 'Paulo Coelho',
    chapters: [
      'Phần 1: Cậu bé chăn cừu Santiago và giấc mơ kho báu',
      'Phần 2: Hành trình băng qua sa mạc đầy nắng gió',
      'Phần 3: Gặp gỡ nhà giả kim và bài học từ gió cát',
      'Phần 4: Kho báu thực sự ở vạch đích đại kim tự tháp',
    ],
  ),
];

class BookLibraryScreen extends StatefulWidget {
  const BookLibraryScreen({super.key});

  @override
  State<BookLibraryScreen> createState() => _BookLibraryScreenState();
}

class _BookLibraryScreenState extends State<BookLibraryScreen> {
  String savedBookTitle = "Chưa có";
  String savedChapter = "";

  void updateBookmark(String bookTitle, String chapterName) {
    setState(() {
      savedBookTitle = bookTitle;
      savedChapter = chapterName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư Viện Sách'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2DD4BF), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔖 BOOKMARK GẦN NHẤT:', style: TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('Sách: $savedBookTitle', style: const TextStyle(fontSize: 14)),
                  if (savedChapter.isNotEmpty)
                    Text('Đang đọc: $savedChapter', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('DANH SÁCH SÁCH TỐI THIỂU:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: sampleBooks.length,
                itemBuilder: (context, index) {
                  final book = sampleBooks[index];
                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.book, color: Color(0xFF2DD4BF)),
                      title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(book.author),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookTocScreen(
                              book: book,
                              onBookmarkSaved: updateBookmark,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class BookTocScreen extends StatelessWidget {
  final Book book;
  final Function(String, String) onBookmarkSaved;

  const BookTocScreen({
    super.key,
    required this.book,
    required this.onBookmarkSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tác giả: ${book.author}', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 20),
            const Text('MỤC LỤC CHI TIẾT:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2DD4BF))),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: book.chapters.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1E293B),
                      child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF2DD4BF))),
                    ),
                    title: Text(book.chapters[index]),
                    trailing: const Icon(Icons.chrome_reader_mode, size: 20),
                    onTap: () {
                      // Chuyển sang Màn hình 3: Đọc sách và truyền dữ liệu qua lại
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookContentScreen(
                            bookTitle: book.title,
                            chapterName: book.chapters[index],
                            chapterIndex: index + 1,
                            onBookmarkSaved: onBookmarkSaved,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class BookContentScreen extends StatelessWidget {
  final String bookTitle;
  final String chapterName;
  final int chapterIndex;
  final Function(String, String) onBookmarkSaved;

  const BookContentScreen({
    super.key,
    required this.bookTitle,
    required this.chapterName,
    required this.chapterIndex,
    required this.onBookmarkSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chương $chapterIndex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add, color: Color(0xFF2DD4BF)),
            tooltip: 'Lưu Bookmark',
            onPressed: () {
              // Thực hiện truyền dữ liệu ngược về màn hình chính thông qua Callback hàm
              onBookmarkSaved(bookTitle, chapterName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('➔ Đã lưu vị trí đọc: $chapterName'),
                  backgroundColor: const Color(0xFF2DD4BF),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapterName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2DD4BF)),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Đây là nội dung văn bản giả lập nhằm phục vụ bài thực hành trên lớp lấy điểm phân hệ UI/UX cơ bản của FPT University. Hệ thống đã triển khai cấu hình viewport cuộn độc lập thông qua SingleChildScrollView để triệt tiêu hoàn toàn lỗi tràn layout dữ liệu hình ảnh cấu trúc.\n\nNgười dùng có thể tự do bấm vào biểu tượng Bookmark trên thanh AppBar góc phải màn hình để ghi nhận và lưu trạng thái trang đang đọc ngầm, sau đó hệ thống sẽ đồng bộ hiển thị dữ liệu trạng thái này ngay tại màn hình Dashboard trang chủ khi quay trở ra.',
              style: TextStyle(fontSize: 16, height: 1.6, color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
      ),
    );
  }
}