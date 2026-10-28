import com.shoutsocial.share_handler.IncomingFile;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class IncomingFileTest {
  public static void main(String[] args) throws Exception {
    Path cache = Files.createTempDirectory("modu-incoming-test-");
    try {
      Files.createDirectory(cache.resolve("National-Post-23-october.pdf"));
      File one = IncomingFile.INSTANCE.copy(cache.toFile(), "National-Post-23-october.pdf", "pdf",
        () -> new ByteArrayInputStream("one".getBytes()));
      File two = IncomingFile.INSTANCE.copy(cache.toFile(), "National-Post-23-october.pdf", "pdf",
        () -> new ByteArrayInputStream("two".getBytes()));
      if (!one.isFile() || one.equals(two)) throw new AssertionError("same-name isolation failed");
      if (!Files.readString(one.toPath()).equals("one") || !Files.readString(two.toPath()).equals("two"))
        throw new AssertionError("bytes overwritten");
      File safe = IncomingFile.INSTANCE.copy(cache.toFile(), "../../outside\\book", "epub",
        () -> new ByteArrayInputStream(new byte[]{1}));
      if (!safe.getName().equals("book.epub") || !safe.toPath().startsWith(cache))
        throw new AssertionError("unsafe filename or missing extension");
      long before;
      try (var files = Files.list(cache)) { before = files.count(); }
      try {
        IncomingFile.INSTANCE.copy(cache.toFile(), "empty.pdf", "pdf", () -> null);
        throw new AssertionError("null stream accepted");
      } catch (Exception expected) { if (!(expected instanceof IOException)) throw expected; }
      try {
        IncomingFile.INSTANCE.copy(cache.toFile(), "partial.pdf", "pdf", () -> new InputStream() {
          public int read() throws IOException { throw new IOException("revoked grant"); }
        });
        throw new AssertionError("read failure accepted");
      } catch (Exception expected) { if (!(expected instanceof IOException)) throw expected; }
      try (var files = Files.list(cache)) {
        if (files.count() != before) throw new AssertionError("partial staging not removed");
      }
      System.out.println("IncomingFile: collision, independent bytes, names, MIME extension, null stream and partial cleanup passed");
    } finally {
      try (var files = Files.walk(cache)) {
        files.sorted(Comparator.reverseOrder()).forEach(path -> {
          try { Files.delete(path); } catch (IOException e) { throw new UncheckedIOException(e); }
        });
      }
    }
  }
}
