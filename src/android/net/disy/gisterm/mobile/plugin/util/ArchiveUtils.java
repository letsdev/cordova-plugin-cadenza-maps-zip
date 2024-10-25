package net.disy.gisterm.mobile.plugin.util;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Constructor;

import net.disy.gisterm.mobile.plugin.ui.ProgressMonitor;

import org.apache.commons.compress.archivers.ArchiveEntry;
import org.apache.commons.compress.archivers.ArchiveInputStream;
import org.apache.commons.compress.archivers.ArchiveOutputStream;

import android.util.Log;

public class ArchiveUtils {

  public static int unpack(ProgressMonitor progressMonitor, File archiveFile, File destinationDirectory, Class<? extends ArchiveInputStream> archiveInputStreamClass) throws IOException {
    FileInputStream fis = null;
    BufferedInputStream bis = null;
    ArchiveInputStream ais = null;
    try {
      fis = new FileInputStream(archiveFile);
      bis = new BufferedInputStream(fis);
      progressMonitor.start();
      Constructor<? extends ArchiveInputStream> ctor = archiveInputStreamClass.getConstructor(InputStream.class);
      ais = ctor.newInstance(bis);
      return ArchiveUtils.unpack(progressMonitor, archiveFile.length(), ais, destinationDirectory);
    } catch (IOException ioe) {
      throw ioe;
    } catch (Exception e) {
      throw new IllegalStateException("Unexpected exception occurred trying to create "
          + "the ArchiveInputStream: " + e.getMessage(), e);
    }
    finally {
      IOUtils.closeQuietly(ais);
      IOUtils.closeQuietly(bis);
      IOUtils.closeQuietly(fis);
      progressMonitor.finish();
    }
  }

  public static int unpack(ProgressMonitor progressMonitor, long fileSize, ArchiveInputStream ais, File destinationDirectory) throws IOException {
    Ensure.ensurePrecondition(destinationDirectory.exists(),
        "Destination directory must exist for unpacking.");
    int extractedFilesCount = 0;
    int oldPercent = -1;
    long oldTimeStamp = System.currentTimeMillis();
    long progressUpdateMinimalDelay = 750;
    for (ArchiveEntry tarEntry = ais.getNextEntry(); tarEntry != null; tarEntry = ais.getNextEntry()) {
      final File destEntryFile = new File(destinationDirectory, tarEntry.getName());
      if (tarEntry.isDirectory()) {
        Log.d("GTM", "Extracting directory [" + tarEntry.getName() + "].");
        destEntryFile.mkdirs();
      } else if (destEntryFile.getName().equals(destinationDirectory.getName())) {
        Log.d("GTM", "We have a tar entry that has the same name as the actual directory and "
                + "pretends it is a file, ignoring it: " + destEntryFile.getName());
      } else {
        destEntryFile.getParentFile().mkdirs();
        extractedFilesCount++;
        FileOutputStream fos = new FileOutputStream(destEntryFile);
        BufferedOutputStream bos = new BufferedOutputStream(fos);
        try {
          IOUtils.copy(ais, bos);
    	  int percent = (int) (ais.getBytesRead() * 100 / fileSize);
        long timeStamp = System.currentTimeMillis();
    	  if (percent-oldPercent>=1 && timeStamp - oldTimeStamp > progressUpdateMinimalDelay) {
          oldTimeStamp = timeStamp;
          oldPercent = percent;
    		  progressMonitor.setPercent(percent) ;
    	  }
        } finally {
          IOUtils.closeQuietly(bos);
          IOUtils.closeQuietly(fos);
        }
      }
    }
    return extractedFilesCount;
  }

  public static int pack(File sourceDirectory, File archiveFile, Class<? extends ArchiveOutputStream> archiveOutputStreamClass) throws IOException {
    ArchiveOutputStream aos = null;
    FileOutputStream fos = null;
    BufferedOutputStream bos = null;
    boolean errorOccurred = false;
    try {
      fos = new FileOutputStream(archiveFile);
      bos = new BufferedOutputStream(fos);
      Constructor<? extends ArchiveOutputStream> ctor = archiveOutputStreamClass.getConstructor(OutputStream.class);
      aos = ctor.newInstance(bos);
      return ArchiveUtils.pack(sourceDirectory, aos);
    } catch (IOException ex) {
      errorOccurred = true;
      throw ex;
    } catch (Exception e) { // not an IOException, possibly related to the reflection we're trying
      errorOccurred = true;
      throw new IllegalStateException("Unexpected exception occurred trying to create "
          + "the ArchiveOutputStream: " + e.getMessage(), e);
    } finally {
      aos.closeArchiveEntry();
      IOUtils.closeQuietly(aos);
      IOUtils.closeQuietly(bos);
      IOUtils.closeQuietly(fos);
      if (errorOccurred) {
        archiveFile.delete();
      }
    }
  }

  public static int pack(File sourceDirectory, ArchiveOutputStream aos) throws IOException {
    File[] files = sourceDirectory.listFiles();
    int count = 0;
    if (files != null) {
      for (File file : files) {
        count += addFileOrDirectory(null, file, aos);
      }
    }
    return count;
  }

  private static int addFileOrDirectory(String parentPath, File file, ArchiveOutputStream zos) throws IOException {
    if (file.isFile()) {
      return addFile(parentPath, file, zos);
    } else {
      return addDirectory(parentPath, file, zos);
    }
  }

  private static int addDirectory(String parentPath, File directory, ArchiveOutputStream zos) throws IOException {
    String path = extendPath(parentPath, directory);
    File[] files = directory.listFiles();
    int count = 0;
    if (files != null) {
      for (File file : files) {
        count += addFileOrDirectory(path, file, zos);
      }
    }
    return count;
  }

  private static int addFile(String parentPath, File file, ArchiveOutputStream aos) throws IOException {
    String path = extendPath(parentPath, file);
    ArchiveEntry entry = aos.createArchiveEntry(file, path);
    aos.putArchiveEntry(entry);
    InputStream fis = new FileInputStream(file);
    try {
      IOUtils.copy(fis, aos);
    } finally {
      IOUtils.closeQuietly(fis);
    }
    return 1;
  }

  private static String extendPath(String parentPath, File file) {
    return (parentPath == null ? "" : parentPath + "/") + file.getName();
  }

}