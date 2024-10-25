package net.disy.gisterm.mobile.plugin.ui;

public interface ProgressMonitor {

  void setPercent(int percent);
  
  void start();

  void finish();
  
}
