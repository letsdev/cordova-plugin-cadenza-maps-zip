package net.disy.gisterm.mobile.plugin;

import java.io.File;
import java.io.IOException;

import net.disy.gisterm.mobile.plugin.archiving.ArchiveHandler;
import net.disy.gisterm.mobile.plugin.archiving.ArchiveProcessingException;
import net.disy.gisterm.mobile.plugin.archiving.TarArchiveHandler;
import net.disy.gisterm.mobile.plugin.archiving.ZipArchiveHandler;
import net.disy.gisterm.mobile.plugin.ui.JavascriptProgressMonitor;
import net.disy.gisterm.mobile.plugin.ui.ProgressMonitor;
import net.disy.gisterm.mobile.plugin.util.FileUtils;	
import net.disy.gisterm.mobile.plugin.util.JsonUtils;

// import org.apache.cordova.DroidGap;
import org.apache.cordova.CordovaActivity;

// import org.apache.cordova.api.Plugin;
import org.apache.cordova.CallbackContext;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

// was Plugin
@SuppressWarnings("nls")
public class GTMZipUtilsPlugin extends CordovaPlugin {

	public static final String ACTION_UNZIP = "unzip";
	public static final String ACTION_ZIP = "zip";
	public static final int ARCHIVE_FILE_DOES_NOT_EXIST = 1;
	public static final int DESTINATION_DIRECTORY_EXISTS = 2;
	public static final int DIRECTORY_COULD_NOT_BE_DELETED = 3;
	public static final int DIRECTORY_COULD_NOT_BE_CREATED = 4;
	public static final int IO_EXCEPTION = 5;
	public static final int INVALID_ARGUMENT_EXCEPTION = 6;
	public static final int JSON_EXCEPTION = 7;
	public static final int ARCHIVE_FILE_EXISTS = 8;
	public static final int TEMPORARY_FILE_COULD_NOT_BE_DELETED = 9;
	public static final int SOURCE_DIRECTORY_DOES_NOT_EXIST = 10;
	public static final int COULD_NOT_MOVE = 11;
	public static final int ARCHIVE_FILE_UNKNOWN_TYPE = 12;

	private static final String FILE_URL_PREFIX = "file://";

	private String callbackId;
	private CallbackContext context;

	private final ArchiveHandler [] archiveHandlers = new ArchiveHandler[] {new TarArchiveHandler(),
		new ZipArchiveHandler()};

	// @Override
	// public PluginResult execute(String action, final JSONArray data, final String callbackId) {
	// 	System.out.println("plugin loaded!");
		

	// 	Log.w("PLUGIN", "GTM Plugin called.");
	// 	PluginResult pr;
	// 	try {
	// 		if (ACTION_UNZIP.equals(action)) {
	// 			pr = createNoPluginResult();
	// 			unpack(data, callbackId);
	// 		} else if (ACTION_ZIP.equals(action)) {
	// 			pr = createNoPluginResult();
	// 			pack(data, callbackId);
	// 		} else {
	// 			Log.e("GTMZipUtilsPlugin", "Invalid action : " + action + " passed");
	// 			pr = createInvalidPluginResult();
	// 		}
	// 	} catch (JSONException je) {
	// 		pr = createJSONExceptionPluginResult(je);
	// 	} catch (ArchiveProcessingException ape) {
	// 		pr = createArchiveExceptionPluginResult(ape);
	// 	}
	// 	return pr;
	// }

	public boolean execute(String action, JSONArray data, final CallbackContext callbackContext) throws JSONException {
	    Log.w("PLUGIN", "GTM Plugin called");
	    // if ("close".equals(action)) {
	    //     cordova.getThreadPool().execute(new Runnable() {
	    //         public void run() {
	    //             //http://stackoverflow.com/a/7696791/1091751
	    //             InputMethodManager inputManager = (InputMethodManager) cordova.getActivity().getSystemService(Context.INPUT_METHOD_SERVICE);
	    //             View v = cordova.getActivity().getCurrentFocus();

	    //             if (v == null) {
	    //                 callbackContext.error("No current focus");
	    //             }
	    //             inputManager.hideSoftInputFromWindow(v.getWindowToken(), InputMethodManager.HIDE_NOT_ALWAYS);
	    //             callbackContext.success(); // Thread-safe.
	    //         }
	    //     });
	    //     return true;
	    // }
	    // if ("show".equals(action)) {
	    //     cordova.getThreadPool().execute(new Runnable() {
	    //         public void run() {
	    //             ((InputMethodManager) cordova.getActivity().getSystemService(Context.INPUT_METHOD_SERVICE)).toggleSoftInput(0, InputMethodManager.HIDE_IMPLICIT_ONLY);
	    //             callbackContext.success(); // Thread-safe.
	    //         }
	    //     });
	    //     return true;
	    // }
	    // return false;  // Returning false results in a "MethodNotFound" error.
	    callbackId = callbackContext.getCallbackId();
	    context = callbackContext;
	    Log.w("PLUGIN", callbackId);

	     	PluginResult pr;
	    		try {
	    			if (ACTION_UNZIP.equals(action)) {
	    Log.w("PLUGIN", "unpack");
	    				pr = createNoPluginResult();
	    				unpack(data, callbackId);
	    			} else if (ACTION_ZIP.equals(action)) {
	    				pr = createNoPluginResult();
	    				pack(data, callbackId);
	    			} else {
	    				Log.e("GTMZipUtilsPlugin", "Invalid action : " + action + " passed");
	    				pr = createInvalidPluginResult();
	    			}
	    		} catch (JSONException je) {
	    			pr = createJSONExceptionPluginResult(je);
	    		} catch (ArchiveProcessingException ape) {
	    			pr = createArchiveExceptionPluginResult(ape);
	    		}
	    return true;
	}


	private void unpack(JSONArray data, final String callbackId)
			throws JSONException, ArchiveProcessingException {
				Log.w("PLUGIN", "unpack entered");
		if (data.length() != 3) {
			throw new ArchiveProcessingException(INVALID_ARGUMENT_EXCEPTION,
					String.format("Invalid input arguments count [%s] - expected arguments "
					+ "[archiveFile, destinationDirectory, temporaryDirectory].", data.length()));
		}
		final String archiveFileName = data.getString(0);
		final String destinationDirName = data.getString(1);
		final String tempDirName = data.getString(2);
		Thread t = new Thread(new Runnable() {
			@Override
			public void run() {
				try {
					int extractedFilesCount = unpack(archiveFileName, destinationDirName, tempDirName);
					JSONObject extractionInfo = createExtractionInfo(archiveFileName, destinationDirName, extractedFilesCount);
					PluginResult pr = createOkPluginResult(extractionInfo);
	    Log.w("PLUGIN", "context send success");
	    Log.w("PLUGIN", extractionInfo.toString());
					context.sendPluginResult(pr);
					// success(pr, callbackId);
				} catch (ArchiveProcessingException ape) {
					PluginResult pr = createArchiveExceptionPluginResult(ape);
					context.sendPluginResult(pr);
					// error(pr, callbackId);
				} catch (JSONException je) {
					PluginResult pr = createJSONExceptionPluginResult(je);
					context.sendPluginResult(pr);
					// error(pr, callbackId);
				}
			}
		});
		t.start();
	}

	private void pack(JSONArray data, final String callbackId)
			throws JSONException, ArchiveProcessingException {
		if (data.length() != 3) {
			throw new ArchiveProcessingException(INVALID_ARGUMENT_EXCEPTION,
					String.format("Invalid input arguments count [{0}] - expected arguments "
					+ "[sourceDirectory, archiveFile, temporaryFile].", data.length()));
		}
		final String sourceDirectoryName = data.getString(0);
		final String archiveFileName = data.getString(1);
		final String tempFileName = data.getString(2);
		Thread t = new Thread(new Runnable(){
			@Override
			public void run() {
				try {
					int compressedFileCount = pack(sourceDirectoryName, archiveFileName, tempFileName);
					JSONObject compressionInfo = createCompressionInfo(sourceDirectoryName, archiveFileName, compressedFileCount);
					PluginResult pr = createOkPluginResult(compressionInfo);
					context.sendPluginResult(pr);
					// success(pr, callbackId);
				} catch (ArchiveProcessingException ape) {
					PluginResult pr = createArchiveExceptionPluginResult(ape);
					context.sendPluginResult(pr);
					// error(pr, callbackId);
				} catch (JSONException je) {
					PluginResult pr = createJSONExceptionPluginResult(je);
					context.sendPluginResult(pr);
					// error(pr, callbackId);
				}
			}
		});
		t.start();
	}

	private int unpack(String archiveFileName, String destinationDirectoryName,
			String tempDirectoryName) throws ArchiveProcessingException {
		final File archiveFile = new File(stripFilePrefix(archiveFileName));
		File destinationDirectory = new File(stripFilePrefix(destinationDirectoryName));
		File tempDirectory = new File(stripFilePrefix(tempDirectoryName));
		if (!archiveFile.exists()) {
			throw createError(ARCHIVE_FILE_DOES_NOT_EXIST, archiveFileName,
					"Archive file [%s] does not exist.");
		}
		if (destinationDirectory.exists()) {
			throw createError(DESTINATION_DIRECTORY_EXISTS, destinationDirectoryName,
					"Destination directory [%s] already exists.");
		}
		if (tempDirectory.exists()) {
			try {
				FileUtils.deleteDirectory(tempDirectory);
			} catch (IOException e) {
				throw createError(DIRECTORY_COULD_NOT_BE_DELETED, tempDirectoryName,
						"Temporary directory [%s] could not be deleted: " + e.getMessage());
			}
		}
		if (!tempDirectory.mkdirs()) {
			throw createError(DIRECTORY_COULD_NOT_BE_CREATED, tempDirectoryName,
					"Temporary directory [%s] could not be created.");
		}
		Log.d("GTMZipUtilsPlugin", "Extracting archive file");
		try {
			ArchiveHandler archiveHandler = findArchiveHandler(archiveFile);
			if (archiveHandler == null) {
				throw createError(ARCHIVE_FILE_UNKNOWN_TYPE, archiveFileName,
						"Unknown filetype for archive file [%s].");
			}


			// ProgressMonitor progressMonitor = new JavascriptProgressMonitor(cordova, archiveFile.getName());
			ProgressMonitor progressMonitor = new JavascriptProgressMonitor((CordovaActivity)this.cordova.getActivity(), archiveFile.getName());

			int extractedFilesCount = archiveHandler.unpack(progressMonitor, archiveFile, tempDirectory);
			boolean renameSucceeded = tempDirectory.renameTo(destinationDirectory);
			if (renameSucceeded) {
				return extractedFilesCount;
			} else {
				throw createError(COULD_NOT_MOVE, destinationDirectoryName,
						"Error renaming temporary directory to destination directory [%s].");
			}
		} catch (IOException ioEx) {
			throw createError(IO_EXCEPTION, archiveFileName,
					"IOException when extracting archive file [%s]:" + ioEx.getMessage(), ioEx);
		}
	}

	private int pack(String sourceDirectoryName, String archiveFileName, String tempFileName)
			throws ArchiveProcessingException {
		File sourceDirectory = new File(stripFilePrefix(sourceDirectoryName));
		File archiveFile = new File(stripFilePrefix(archiveFileName));
		File tempFile = new File(stripFilePrefix(tempFileName));
		if (!sourceDirectory.exists()) {
			throw createError(SOURCE_DIRECTORY_DOES_NOT_EXIST, sourceDirectoryName,
					"Source directory [%s] does not exist.");
		}
		if (archiveFile.exists()) {
			throw createError(ARCHIVE_FILE_EXISTS, archiveFileName, "Archive file [%s] exists.");
		}
		//TODO Review ik/ks: What if tempfile deletion fails???
		if (tempFile.exists()) {
			tempFile.delete();
		}
		Log.d("GTMZipUtilsPlugin", "Compressing archive file.");
		try {
			ArchiveHandler archiveHandler = new ZipArchiveHandler();
			int compressedFileCount = archiveHandler.pack(sourceDirectory, tempFile);
			final boolean renameSucceeded = tempFile.renameTo(archiveFile);
			if (archiveFile.exists() && sourceDirectory.exists()) {
				FileUtils.deleteDirectory(sourceDirectory);
			}
			if (renameSucceeded) {
				return compressedFileCount;
			} else {
				throw createError(COULD_NOT_MOVE, archiveFileName,
						"Error renaming temporary archive to final archive file [%s].");
			}
		} catch (IOException ioEx) {
			throw createError(IO_EXCEPTION, archiveFileName,
				"IOException by packing archive file [%s] occurred: " + ioEx.getMessage(), ioEx);
		}
	}

	private JSONObject createExtractionInfo(String archiveFileName,
			String destinationDirectoryName, int extractedFilesCount) throws JSONException {
		return new JSONObject()
			.put("extractedFileCount", extractedFilesCount)
			.put("archiveFileName", archiveFileName)
			.put("destinationDirectoryName", destinationDirectoryName);
	}

	private JSONObject createCompressionInfo(String sourceDirectoryName,
			String archiveFileName, int compressedFilesCount) throws JSONException {
		return new JSONObject()
			.put("compressedFileCount", compressedFilesCount)
			.put("archiveFileName", archiveFileName)
			.put("sourceDirectoryName", sourceDirectoryName);
	}

	private ArchiveProcessingException createError(int code, String path, String unformattedMessage) {
		return createError(code, path, unformattedMessage, null);
	}

	private ArchiveProcessingException createError(int code, String path,  String unformattedMessage,
					Throwable cause) {
		String message = String.format(unformattedMessage, path);
		if (cause != null) {
			Log.e("GTMZipUtilsPlugin", message, cause);
		} else {
			Log.e("GTMZipUtilsPlugin", message);
		}
		return new ArchiveProcessingException(code, path, message);
	}

	private ArchiveHandler findArchiveHandler(File archiveFile) throws IOException {
		for (ArchiveHandler handler : archiveHandlers) {
			if (handler.canHandle(archiveFile)) {
				return handler;
			}
		}
		return null;
	}

	private String stripFilePrefix(String input) {
		return (input.startsWith(FILE_URL_PREFIX) ? input.substring(FILE_URL_PREFIX.length()) : input);
	}

	private PluginResult createNoPluginResult() {
		Log.w("PLUGIN", "createNoPluginResult");
		PluginResult pr;
		pr = new PluginResult(Status.NO_RESULT);
		pr.setKeepCallback(true);
		return pr;
	}

	private PluginResult createInvalidPluginResult() {
		PluginResult pr;
		pr = new PluginResult(Status.INVALID_ACTION);
		return pr;
	}

	private PluginResult createOkPluginResult(JSONObject jsonObject) {
		PluginResult pr = new PluginResult(Status.OK, jsonObject);
		pr.setKeepCallback(false);
		return pr;
	}

	private PluginResult createArchiveExceptionPluginResult(
			ArchiveProcessingException ape) {
		ape.printStackTrace();
		PluginResult pr = new PluginResult(Status.ERROR, ape.toErrorJSONObject());
		pr.setKeepCallback(false);
		return pr;
	}

	private PluginResult createJSONExceptionPluginResult(JSONException je) {
		je.printStackTrace();
		PluginResult pr = new PluginResult(Status.ERROR,JsonUtils.createErrorJSONObject(
				je.getMessage(), JSON_EXCEPTION));
		pr.setKeepCallback(false);
		return pr;
	}

}
