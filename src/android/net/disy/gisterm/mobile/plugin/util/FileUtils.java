package net.disy.gisterm.mobile.plugin.util;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

public class FileUtils {
  /**
   * Deletes a directory recursively. 
   *
   * @param directory  directory to delete
   * @throws IOException in case deletion is unsuccessful
   */
  public static void deleteDirectory(File directory) throws IOException {
    if (!directory.exists()) {
      return;
    }

    if (!isSymlink(directory)) {
      cleanDirectory(directory);
    }

    if (!directory.delete()) {
      String message = "Unable to delete directory " + directory + "."; //$NON-NLS-1$ //$NON-NLS-2$
      throw new IOException(message);
    }
  }

  /**
   * Determines whether the specified file is a Symbolic Link rather than an actual file.
   * <p>
   * Will not return true if there is a Symbolic Link anywhere in the path,
   * only if the specific file is.
   * <p>
   * <b>Note:</b> the current implementation always returns {@code false} if the system
   * is detected as Windows using {@link FilenameUtils#isSystemWindows()}
   * 
   * @param file the file to check
   * @return true if the file is a Symbolic Link
   * @throws IOException if an IO error occurs while checking the file
   */
  public static boolean isSymlink(File file) throws IOException {
    if (file == null) {
      throw new NullPointerException("File must not be null"); //$NON-NLS-1$
    }
    if (FilenameUtils.isSystemWindows()) {
      return false;
    }
    File fileInCanonicalDir = null;
    if (file.getParent() == null) {
      fileInCanonicalDir = file;
    }
    else {
      File canonicalDir = file.getParentFile().getCanonicalFile();
      fileInCanonicalDir = new File(canonicalDir, file.getName());
    }

    if (fileInCanonicalDir.getCanonicalFile().equals(fileInCanonicalDir.getAbsoluteFile())) {
      return false;
    }
    else {
      return true;
    }
  }

  /**
   * Cleans a directory without deleting it.
   *
   * @param directory directory to clean
   * @throws IOException in case cleaning is unsuccessful
   */
  public static void cleanDirectory(File directory) throws IOException {
    if (!directory.exists()) {
      String message = directory + " does not exist"; //$NON-NLS-1$
      throw new IllegalArgumentException(message);
    }

    if (!directory.isDirectory()) {
      String message = directory + " is not a directory"; //$NON-NLS-1$
      throw new IllegalArgumentException(message);
    }

    File[] files = directory.listFiles();
    if (files == null) { // null if security restricted
      throw new IOException("Failed to list contents of " + directory); //$NON-NLS-1$
    }

    IOException exception = null;
    for (File file : files) {
      try {
        forceDelete(file);
      }
      catch (IOException ioe) {
        exception = ioe;
      }
    }

    if (null != exception) {
      throw exception;
    }
  }

  /**
   * Deletes a file. If file is a directory, delete it and all sub-directories.
   * <p>
   * The difference between File.delete() and this method are:
   * <ul>
   * <li>A directory to be deleted does not have to be empty.</li>
   * <li>You get exceptions when a file or directory cannot be deleted.
   *      (java.io.File methods returns a boolean)</li>
   * </ul>
   *
   * @param file  file or directory to delete, must not be {@code null}
   * @throws NullPointerException if the directory is {@code null}
   * @throws FileNotFoundException if the file was not found
   * @throws IOException in case deletion is unsuccessful
   */
  public static void forceDelete(File file) throws IOException {
    if (file.isDirectory()) {
      deleteDirectory(file);
    }
    else {
      boolean filePresent = file.exists();
      if (!file.delete()) {
        if (!filePresent) {
          throw new FileNotFoundException("File does not exist: " + file); //$NON-NLS-1$
        }
        String message = "Unable to delete file: " + file; //$NON-NLS-1$
        throw new IOException(message);
      }
    }
  }
  
  public static boolean hasMatchingSignature(InputStream is, int [] signature) 
		  throws IOException {
		int b;
		int index = 0;
		while ((b = is.read()) != -1 && (index < signature.length)) {
			if (b != signature[index]) {
				return false;
			}
			index++;
		}
		// we have to make sure that the entire signature was checked (inputstream could be shorter 
		// than signature)
		return index == signature.length;
  }
  
}
