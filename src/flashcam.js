// Use jscompress.com to compress this file

;(function($) {
	$.fn.flashcam = function(options) {
		// merge passed options with default values
		var opts = $.extend({}, $.fn.flashcam.defaults, options);
		// off we go
		return this.each(function() {
			// add flash to div
			opts.id = this.id; // add id of plugin to the options structure
			data = opts; // pass options to jquery internal data field to make them available to the outside world
			data.path = decodeURIComponent(data.path); // convert URI back to normal string

			$('#'+opts.id).html(opts.noFlashFound); // inject no flash found message

			// forward incoming flash movie calls to outgoing functions
			$.flashcam.FC_onConnect = data.onConnect;
			$.flashcam.FC_onDisconnect = data.onDisconnect;
			$.flashcam.FC_onError = data.onError;
			$.flashcam.FC_onShow = data.onShow;
			$.flashcam.FC_onWebcamReady = data.onWebcamReady;
      $.flashcam.FC_onTimeLeftChange = data.onTimeLeftChange;

			var newWidth = opts.width;
			var newHeight = opts.height;

			// use GPU acceleration
			var params = {
				menu: 'false',
				wmode: 'direct'
			};

			// Escape all values contained in the flashVars (IE needs this)
			for (var key in opts) {
				opts[key] = encodeURIComponent(opts[key]);
			};

			swfobject.embedSWF(data.path + 'flashcam.swf', opts.id, newWidth, newHeight, '11.4', false, opts, params);
		});
	};

	$.flashcam = {};
	
	// outgoing functions (calling the flash movie)
	
  function FC_display() {
    return $('#' + data.id).get(0);
  }

	$.flashcam.version = function() {
		return FC_display().FC_version();
	}

	$.flashcam.recordStart = function() {
    FC_display().FC_recordStart();
	}

	$.flashcam.recordStop = function() {
    FC_display().FC_recordStop();
	}

	$.flashcam.recordPlayback = function() {
    FC_display().FC_recordPlayback();
	}

	// set javascript default values (flash default values are managed in the swf file)
	$.fn.flashcam.defaults = {
		width:320,
		height:240,
		path:'',
		noFlashFound:'<p>You need <a href="http://www.adobe.com/go/getflashplayer">Adobe Flash Player 11.4</a> to use this software.<br/>Please click on the link to download the installer.</p>'
	};
})(jQuery);

// incoming functions (calls coming from flash) - must be public and forward calls to the flashcam plugin

function FC_onError(errorId, errorMsg) {
	$.flashcam.FC_onError(errorId, errorMsg);
}

function FC_onShow() {
	$.flashcam.FC_onShow();
}

function FC_onConnect() {
	$.flashcam.FC_onConnect();
}

function FC_onDisconnect() {
	$.flashcam.FC_onDisconnect();
}

function FC_onWebcamReady() {
  $.flashcam.FC_onWebcamReady()
}

function FC_onTimeLeftChange() {
	$.flashcam.FC_onTimeLeftChange();
}
