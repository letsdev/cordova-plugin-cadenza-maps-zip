// cordova.define("net.disy.cm.zip.GTMZipUtilsPlugin", function(require, exports, module) { var GTMZipUtilsPlugin = function() {
// };

/**
 * This is the interface to the native zip plugin. The unzip-method extract a
 * archive file into destination directory using the temporary directory where
 * the archive file is first extracted.
 *
 * @param archiveFilePath
 *            The archive file which we want to extract
 * @param destinationDirectoryPath
 *            Directory in which the archive file will be extracted. This
 *            directory must not exists on the file system and will be created
 *            by extraction process.
 * @param temporaryDirectoryPath
 *            Directory in which the archive file will be extracted temporary.
 * @param successCallback -
 *            The callback which will be called when extraction is successful.
 * @param failureCallback -
 *            The callback which will be called when extraction encounters an
 *            error.
 */
// GTMZipUtilsPlugin.prototype.unzip = function(archiveFilePath, destinationDirectoryPath, temporaryDirectoryPath, successCallback, failureCallback) {
// 	return cordova.exec(successCallback, failureCallback, 'GTMZipUtilsPlugin', 'unzip', [ archiveFilePath, destinationDirectoryPath, temporaryDirectoryPath ]);
// };

/**
 * This is the interface to the native zip plugin. The zip-method compresses the
 * source directory into the archive file using the temporary file where the
 * source directory is first compressed.
 *
 * @param sourceDirectoryPath
 *            Directory which contains files to be compressed. This directory
 *            must exists on the file system.
 * @param archiveFilePath
 *            Target archive file, must not exist.
 * @param temporaryFilePath
 *            Temporary file where the source directory will be compressed
 *            temporarily.
 * @param successCallback -
 *            The callback which will be called when compression is successful.
 * @param failureCallback -
 *            The callback which will be called when compression encounters an
 *            error.
 */
// GTMZipUtilsPlugin.prototype.zip = function(sourceDirectoryPath, archiveFilePath, temporaryFilePath, successCallback, failureCallback) {
// 	return cordova.exec(successCallback, failureCallback, 'GTMZipUtilsPlugin', 'zip', [ sourceDirectoryPath, archiveFilePath, temporaryFilePath ]);
// };

// GTMZipUtilsPlugin.install = function(){
// 	if(!window.plugins) {
//         window.plugins = {};
//     }
//     if ( ! window.plugins.GTMZipUtilsPlugin ) {
//         window.plugins.GTMZipUtilsPlugin = new GTMZipUtilsPlugin();
//     }
// };

// cordova.addConstructor(GTMZipUtilsPlugin.install);


// });

cordova.define("net.disy.cm.zip.GTMZipUtilsPlugin", function(require, exports, module) {
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');

var GTMZipUtilsPlugin = function() {
	console.log("this here");

};

GTMZipUtilsPlugin.unzip = function(archiveFilePath, destinationDirectoryPath, temporaryDirectoryPath, successCallback, failureCallback) {
    exec(successCallback, failureCallback, 'GTMZipUtilsPlugin', 'unzip', [ archiveFilePath, destinationDirectoryPath, temporaryDirectoryPath ]);
};

GTMZipUtilsPlugin.zip = function(sourceDirectoryPath, archiveFilePath, temporaryFilePath, successCallback, failureCallback) {
	exec(successCallback, failureCallback, 'GTMZipUtilsPlugin', 'zip', [ sourceDirectoryPath, archiveFilePath, temporaryFilePath ]);
};

// Keyboard.show = function() {
//  exec(null, null, "Keyboard", "show", []);
// };

// Keyboard.disableScroll = function(disable) {
//  exec(null, null, "Keyboard", "disableScroll", [disable]);
// };

/*
Keyboard.styleDark = function(dark) {
 exec(null, null, "Keyboard", "styleDark", [dark]);
};
*/

module.exports = GTMZipUtilsPlugin;




});

