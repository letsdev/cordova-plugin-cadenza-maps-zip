package net.disy.gisterm.mobile.plugin.util;

import java.io.File;

public class FilenameUtils {
  private static final char SYSTEM_SEPARATOR = File.separatorChar;
  private static final char WINDOWS_SEPARATOR = '\\';

  /**
   * Determines if Windows file system is in use.
   * 
   * @return true if the system is Windows
   */
  static boolean isSystemWindows() {
    return SYSTEM_SEPARATOR == WINDOWS_SEPARATOR;
  }
}
