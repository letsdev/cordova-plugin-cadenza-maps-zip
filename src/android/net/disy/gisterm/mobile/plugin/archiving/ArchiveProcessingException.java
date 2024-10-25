package net.disy.gisterm.mobile.plugin.archiving;

import net.disy.gisterm.mobile.plugin.util.JsonUtils;
import org.json.JSONObject;

public class ArchiveProcessingException extends Exception {
	
	int code;
	String path;
	
	public ArchiveProcessingException(int code, String message) {
		super(message);
		this.code = code;
	}
	
	public ArchiveProcessingException(int code, String path, String message) {
		super(message);
		this.code = code;
		this.path = path;
	}

	public int getCode() {
		return code;
	}

	public String getPath() {
		return path;
	}	
	
	public JSONObject toErrorJSONObject() {
		return JsonUtils.createErrorJSONObject(getMessage(), code, path);
	}
	
}