package net.disy.gisterm.mobile.plugin.util;

import org.json.JSONException;
import org.json.JSONObject;

/**
 *
 * @author terzic
 */
public class JsonUtils {

	public static JSONObject createErrorJSONObject(String message, int code) {
		try {
			JSONObject jsonObject = new JSONObject().put("message", message).put("code", code);
			return jsonObject;
		} catch (JSONException jsonEx) {
			throw new IllegalArgumentException(jsonEx);
		}
	}

	public static JSONObject createErrorJSONObject(String message, int code, String fullPath) {
		try {
			JSONObject jsonObject = createErrorJSONObject(message, code).put("fullPath", fullPath);
			return jsonObject;
		} catch (JSONException jsonEx) {
			throw new IllegalArgumentException(jsonEx);
		}
	}
	
}
