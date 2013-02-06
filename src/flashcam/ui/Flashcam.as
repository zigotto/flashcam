package flashcam.ui
{
	// Imports
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.H264Level;
	import flash.media.H264Profile;
	import flash.media.H264VideoStreamSettings;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.system.Capabilities;

	import mx.core.Application;
	import mx.events.FlexEvent;

	public class Flashcam extends Application
	{	
		// software version
		private var version:String = "0.0.1";

		// server address const
		private var rtmp_server:String = "rtmp://localhost/vod";
		//private var rtmp_server:String = "rtmp://177.71.245.129:1935/vod";

		// components to show your video
		private var video_url:String = "mp4:interview.f4v";
		private var video:Video;
		private var display:VideoContainer;
		private var cam:Camera;
		private var mic:Microphone;
		private var stream:NetStream;
		private var connection:NetConnection;
		private var h264Settings:H264VideoStreamSettings;

		public function Flashcam()
		{
			this.addEventListener(FlexEvent.CREATION_COMPLETE, this.handleComplete);
		}

		private function handleComplete( event : FlexEvent ) : void {
			log("Flashcam (" + this.flashcamVersion() + ") created");
			logFlashPlayerType();

			init();
		}
		
		private function createVideoDisplay():void
		{
			log('Creating video display');

			this.display = new VideoContainer();
			this.display.id = "flashContent";
			this.display.width = this.width;
			this.display.height = this.height;
			this.addChild(display);
		}

		private function logFlashPlayerType():void
		{
			var flashPlayerType:String;
			
			if (Capabilities.isDebugger) flashPlayerType;
			else flashPlayerType;

			log(flashPlayerType + " " + Capabilities.playerType + " (" + Capabilities.version + ")");
		}
		
		private function init():void
		{
			createVideoDisplay();
			initializeCamera();
			initializeMicrophone();
			initializeConnection();
			createInterfaceCallbacks();

			this.display.video = this.video;
		}

		private function createInterfaceCallbacks():void
		{
			log("Adding ExternalInterface");
			ExternalInterface.addCallback("FC_version", this.flashcamVersion);
		}

		private function initializeConnection():void
		{
			this.connection = new NetConnection();
			this.connection.addEventListener(NetStatusEvent.NET_STATUS, this.netStatusHandler);
			this.connection.client = this;
			this.connection.connect(this.rtmp_server);

			log("Connected: " + this.connection.connected);
		}

		private function initializeCamera():void
		{
			this.video = new Video();
			this.video.opaqueBackground = true;

			this.cam = Camera.getCamera();

			if (this.cam != null)
			{
				this.configureH264();

				this.cam.setKeyFrameInterval(15);
				this.cam.setQuality(0, 90);
				this.cam.setLoopback(false);
				this.cam.addEventListener(StatusEvent.STATUS, this.statusHandler);
				this.video.attachCamera(this.cam);

				log("Camera: Bandwidth: " + this.cam.bandwidth.toString());
				log("Camera: Current FPS: " + this.cam.currentFPS.toString());
				log("Camera: FPS: " + this.cam.fps.toString());
				log("Camera: Keyframe Interval: " + this.cam.keyFrameInterval.toString());
				log("Camera: Quality: " + this.cam.quality.toString());

				log("Camera plugged in!");
				ExternalInterface.call("FC_showPrompt");
			} else {
				log("You don't have a camera!");
			}
		}

		private function configureH264():void
		{
			log("Init H264 encoder");

			this.h264Settings = new H264VideoStreamSettings();
			this.h264Settings.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3);
			this.h264Settings.setKeyFrameInterval(15);
			this.h264Settings.setQuality(0, 90);
			this.h264Settings.setMode(this.video.videoWidth, this.video.videoHeight, -1);
			
			log("h264Settings: Video codec used for compression: " + this.h264Settings.codec);
			log("h264Settings: Level used for H.264/AVC encoding: " + this.h264Settings.level);
			log("h264Settings: Profile used for H.264/AVC encoding: " + this.h264Settings.profile);
			log("h264Settings: Bandwidth: " + this.h264Settings.bandwidth.toString());
			log("h264Settings: FPS: " + this.h264Settings.fps.toString());
			log("h264Settings: Keyframe interval: " + this.h264Settings.keyFrameInterval.toString());
			log("h264Settings: Quality: " + this.h264Settings.quality.toString());
		}

		private function initializeMicrophone():void
		{
			this.mic = Microphone.getMicrophone();
			this.mic.setUseEchoSuppression(true);
			this.mic.setSilenceLevel(0);

			if (this.mic != null)
			{
				this.mic.addEventListener(StatusEvent.STATUS, this.onMicStatus);

				log("Microphone plugged in!");
			} else {
				log("You don't have a microphone!");
			}
		}
		
		private function statusHandler(event:StatusEvent):void
		{
			// This event gets dispatched when the user clicks the "Allow" or "Deny"
			// button in the Flash Player Settings dialog box.
			trace(event.code); // "Camera.Muted" or "Camera.Unmuted"
			log(event.code);
		}
		
		private function netStatusHandler(event:NetStatusEvent):void
		{
			// This event gets dispatched whether the connection
			// could be completed or not.
			trace(event.info.code); // "NetConnection.Connect.Success" or "NetConnection.Connect.Failed"
			log(event.info.code);
		}
		
		private function onMicStatus(event:StatusEvent):void
		{
			if (event.code == "Microphone.Unmuted")
			{
				log("Microphone access was allowed.");
			}
			else if (event.code == "Microphone.Muted")
			{
				log("Microphone access was denied.");
			}
		}

		// video streaming
		public function recordStart():void
		{
			log("Record: start");

			this.stream = new NetStream(this.connection);
			this.stream.client = this;
			this.stream.videoStreamSettings = this.h264Settings;
			this.stream.attachAudio(this.mic);
			this.stream.attachCamera(this.cam);
			this.stream.publish(this.video_url, "record");

			this.video.attachCamera(this.cam);

			log("Record using codec: " + this.stream.videoStreamSettings.codec);
		}
		public function recordStop():void
		{
			log("Record: stop");

			this.stream.close();
			this.video.attachCamera(null);
		}

		public function recordPlay():void
		{
			log("Record: play");

			this.stream = new NetStream(this.connection);
			this.stream.client = this;
			this.stream.play(this.video_url);
			this.video.attachNetStream(this.stream);
		}

		public function onBWCheck(... args):Number
		{
			return 0;
		}

		public function onBWDone(... args):void
		{
			if (args.length > 0) args = args[0];
			Flashcam.log("Detected bandwidth: " + args + " Kbps.");
			return;
		}

		public function flashcamVersion():String
		{
			return this.version;
		}

		public static function log(text:String):void
		{
			if (ExternalInterface.available)
			{
				ExternalInterface.call("console.log", text);
			}
			return;
		}

		private static function showError(id:Number, text:String):void
		{
			log(text);

			if (ExternalInterface.available)
			{
				ExternalInterface.call("FC_onError", id, text);
			}
			return;
		}
	}
}