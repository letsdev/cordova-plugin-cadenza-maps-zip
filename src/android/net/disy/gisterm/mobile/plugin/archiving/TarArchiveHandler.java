package net.disy.gisterm.mobile.plugin.archiving;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import net.disy.gisterm.mobile.plugin.ui.ProgressMonitor;
import net.disy.gisterm.mobile.plugin.util.ArchiveUtils;
import net.disy.gisterm.mobile.plugin.util.FileUtils;
import net.disy.gisterm.mobile.plugin.util.IOUtils;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream;

public class TarArchiveHandler implements ArchiveHandler {

  // See http://www.astro.keele.ac.uk/oldusers/rno/Computing/File_magic.html
  private static final int[] TAR_SIGNATURE = {0x75, 0x73, 0x74, 0x61, 0x72};

  @Override
  public boolean canHandle(File archiveFile) throws IOException {
    FileInputStream fis = new FileInputStream(archiveFile);
    try {
      // TAR signature starts 257 bytes in
      fis.skip(257);
      return FileUtils.hasMatchingSignature(fis, TAR_SIGNATURE);
    } finally {
      IOUtils.closeQuietly(fis);
    }
  }

  @Override
  public int unpack(ProgressMonitor progressMonitor, File archiveFile, File destinationDirectory) throws IOException {
    return ArchiveUtils.unpack(progressMonitor, archiveFile, destinationDirectory, TarArchiveInputStream.class);
  }

  @Override
  public int pack(File sourceDirectory, File archiveFile) throws IOException {
    return ArchiveUtils.pack(sourceDirectory, archiveFile, TarArchiveOutputStream.class);
  }
}
