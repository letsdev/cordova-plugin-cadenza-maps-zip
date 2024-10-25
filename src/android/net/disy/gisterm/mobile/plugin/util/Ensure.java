package net.disy.gisterm.mobile.plugin.util;

public class Ensure {
	public static void ensurePrecondition(boolean value, String description) {
		if (! value) {
			throw new IllegalArgumentException("Precondition not met: " + description);
		}
	}
}
