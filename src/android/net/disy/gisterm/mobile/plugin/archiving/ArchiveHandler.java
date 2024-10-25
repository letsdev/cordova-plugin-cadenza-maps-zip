package net.disy.gisterm.mobile.plugin.archiving;

import java.io.File;
import java.io.IOException;

import net.disy.gisterm.mobile.plugin.ui.ProgressMonitor;

public interface ArchiveHandler {
  
  boolean canHandle(File archiveFile) throws IOException;
  
  int unpack(ProgressMonitor progressMonitor, File archiveFile, File destinationDirectory) throws IOException;
  
  int pack(File sourceDirectory, File archiveFile) throws IOException;
}
