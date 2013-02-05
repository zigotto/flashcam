package flashcam.ui
{

	// Imports
	import flash.system.Capabilities;
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

	//import mx.controls.Alert;

	public class Flashcam
	{	
		private var version:String = "0.0.1";
		
		// server address const
		private var rtmp_server:String = "rtmp://localhost/vod";
		//private var rtmp_server:String = "rtmp://177.71.245.129:1935/vod";

		// components to show your video
		private var video_url:String = "mp4:interview.f4v";
		private var video:Video;
		private var cam:Camera;
		private var mic:Microphone;
		private var stream:NetStream;
		private var connection:NetConnection;

		private var h264Settings:H264VideoStreamSettings;

		public function Flashcam()
		{
			log("Flashcam (" + this.flashcamVersion() + ") created");
		}

		public function initialize():void
		{
			log("Flashcam initialized");

			var flashPlayerType:String;
			if (Capabilities.isDebugger)
			{
				flashPlayerType;
			}
			else
			{
				flashPlayerType;
			}
			log(flashPlayerType + " " + Capabilities.playerType + " (" + Capabilities.version + ")");
			
			initializeCamera();
			initializeMicrophone();
			initializeConnection();
			
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
				this.cam.addEventListener(StatusEvent.STATUS, this.statusHandler);
				this.video.attachCamera(this.cam);

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
			this.h264Settings.setQuality(90000, 90);
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

		public static function log(text:String):void
		{
			if (ExternalInterface.available) {
				ExternalInterface.call("console.log", text);
				// mx.controls.Alert.show(text);
			}
			return;
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

		public function getVideo():Video
		{
			return this.video;
		}
		
		public function flashcamVersion():String
		{
			return this.version;
		}
	}
}