package net.disy.gisterm.mobile.plugin.ui;

// import org.apache.cordova.DroidGap;
import org.apache.cordova.CordovaActivity;

public class JavascriptProgressMonitor implements ProgressMonitor {
    private final String fileName;
    // replaced DroidGap with CordovaActivity, DroidGap is deprecated as of cordova 3+
    private CordovaActivity activity = null;

    public JavascriptProgressMonitor(String fileName) {
        this.fileName = fileName;
    }

    public JavascriptProgressMonitor(CordovaActivity activity, String fileName) {
        this.activity = activity;
        this.fileName = fileName;
    }

    @Override
    public void setPercent(final int percent) {
        if (activity == null) {
            return;
        }

        //System.out.println("Percent asdasd " + percent);
        final Thread thread = new Thread() {
            @Override
            public void run() {
                // droidGap.sendJavascript("GTMS.beanFactory.getBean(\'mapController\').mainView.showLoadMaskDirectly(GTM.I18N.getMessage(\'GTM.GTMZipUtilsPlugin.importRunning.text\', {filename: \'" + fileName + "\', percentage: \'" + percent + "\'}));");
                // droidGap.sendJavascript("console.log(\'import with " + percent + "\')");
                // this seems to replace sendJavascript

                // without the "javascript:" part the app will go to background without a comment and it will extract the archive in background mode
                activity.loadUrl("javascript:var event = document.createEvent(\'CustomEvent\');"
                    + 	"event.initCustomEvent(\'progressUpdate\', true, true, {filename: \'" + fileName + "\', progress:" + percent + ", title: \'Karte importieren\'});"
                    +	"document.dispatchEvent(event);");
            }
        };
        activity.runOnUiThread(thread);
    }

    @Override
    public void start() {
        if (activity == null) {
            return;
        }

        final Thread thread = new Thread() {
            @Override
            public void run() {
                // droidGap.sendJavascript("GTMS.beanFactory.getBean(\'mapController\').mainView.showLoadMaskDirectly(GTM.I18N.getMessage(\'GTM.GTMZipUtilsPlugin.importStart.text\', {filename: \'" + fileName + "\'}));");
                // droidGap.sendJavascript("console.log(\'import start plugin\')");
                // this seems to replace sendJavascript
                activity.loadUrl("javascript:var event = document.createEvent(\'CustomEvent\');"
                    + 	"event.initCustomEvent(\'progressUpdate\', true, true, {filename: \'" + fileName + "\', progress:" + 0 + ", title: \'Karte importieren\'});"
                    +	"document.dispatchEvent(event);");
            }
        };
        activity.runOnUiThread(thread);
    }

    @Override
    public void finish() {
        // Do nothing
    }

}
