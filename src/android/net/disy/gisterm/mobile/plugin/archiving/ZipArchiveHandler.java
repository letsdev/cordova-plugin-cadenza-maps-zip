package net.disy.gisterm.mobile.plugin.archiving;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import net.disy.gisterm.mobile.plugin.ui.ProgressMonitor;
import net.disy.gisterm.mobile.plugin.util.ArchiveUtils;
import net.disy.gisterm.mobile.plugin.util.FileUtils;
import net.disy.gisterm.mobile.plugin.util.IOUtils;
import org.apache.commons.compress.archivers.zip.ZipArchiveInputStream;
import org.apache.commons.compress.archivers.zip.ZipArchiveOutputStream;

public class ZipArchiveHandler implements ArchiveHandler {
  
  // See http://www.astro.keele.ac.uk/oldusers/rno/Computing/File_magic.html
  private static int [] PKZIP_SIGNATURE = new int [] {0x50, 0x4b, 0x03, 0x04};
  
  @Override
  public boolean canHandle(File archiveFile) throws IOException {
    FileInputStream fis = new FileInputStream(archiveFile);
    try {
      return FileUtils.hasMatchingSignature(fis, PKZIP_SIGNATURE);
    } finally {
      IOUtils.closeQuietly(fis);
    }
  }

  @Override
  public int unpack(ProgressMonitor progressMonitor, File archiveFile, File destinationDirectory) throws IOException {
    return ArchiveUtils.unpack(progressMonitor, archiveFile, destinationDirectory, ZipArchiveInputStream.class);
  }
  
  @Override
  public int pack(File sourceDirectory, File archiveFile) throws IOException {
    return ArchiveUtils.pack(sourceDirectory, archiveFile, ZipArchiveOutputStream.class);
  }

}
