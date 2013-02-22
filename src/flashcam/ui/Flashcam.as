package flashcam.ui
{
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
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
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;

	import mx.core.Application;
	import mx.core.FlexGlobals;
	import mx.events.FlexEvent;

	public class Flashcam extends Application
	{	
		// software version
		private var version:String = "0.1.0";

		// server address const
		private var rtmp_server:String = "";

		// components to show your video
		private var fileName:String = "";
		private var video:Video;
		private var display:VideoContainer;
		private var cam:Camera;
		private var mic:Microphone;
		private var stream:NetStream;
		private var connection:NetConnection;
		private var h264Settings:H264VideoStreamSettings;

		private var useH264:Boolean = true;
		private var alreadyRecorded:Boolean = false;

		private var xmlLoader:URLLoader = new URLLoader();

		public function Flashcam()
		{
			this.addEventListener(FlexEvent.CREATION_COMPLETE, this.handleComplete);
		}

		private function handleComplete( event : FlexEvent ) : void {
			log("Flashcam (" + this.flashcamVersion() + ") created");
			logFlashPlayerType();

			xmlLoader.addEventListener(Event.COMPLETE, loadXML, false, 0, true);
			xmlLoader.load(new URLRequest("config.xml"));
		}

		private function loadXML(evt:Event):void
		{
			var config:XML = new XML(evt.target.data);
			this.rtmp_server = config.server;

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
			retrieveFlashvars();
			createVideoDisplay();
			initializeCamera();
			initializeMicrophone();
			initializeConnection();
			createInterfaceCallbacks();
		}

		private function retrieveFlashvars():void
		{
			log("Retrieving flashvars");

			var params:Object = Application(FlexGlobals.topLevelApplication).parameters;

			if (params.fileName) this.fileName = params.fileName;
			if (params.useOldCodec) this.useH264 = false;
		}

		private function createInterfaceCallbacks():void
		{
			log("Adding ExternalInterface");
			ExternalInterface.addCallback("FC_version", this.flashcamVersion);
			ExternalInterface.addCallback("FC_recordStart", this.recordStart);
			ExternalInterface.addCallback("FC_recordStop", this.recordStop);
			ExternalInterface.addCallback("FC_recordPlayback", this.recordPlayback);
		}

		private function initializeConnection():void
		{
			this.connection = new NetConnection();
			this.connection.addEventListener(NetStatusEvent.NET_STATUS, this.netStatusHandler);
			this.connection.addEventListener(AsyncErrorEvent.ASYNC_ERROR, this.netAsyncErrorEvent);
			this.connection.addEventListener(IOErrorEvent.IO_ERROR, this.netIOErrorEvent);
			this.connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.netSecurityErrorEvent);

			this.connection.client = this;
			this.connection.connect(this.rtmp_server);
		}

		private function initializeCamera():void
		{
			this.video = new Video();
			this.video.opaqueBackground = true;

			this.cam = Camera.getCamera();

			if (this.cam != null)
			{
				if (this.useH264) this.h264Settings = this.configureH264();

				this.cam.setKeyFrameInterval(15);
				this.cam.setQuality(0, 90);
				this.cam.setLoopback(false);
				this.cam.addEventListener(StatusEvent.STATUS, this.statusHandler);
				this.video.attachCamera(this.cam);

				this.display.video = this.video;

				log("Camera: Bandwidth: " + this.cam.bandwidth.toString());
				log("Camera: Current FPS: " + this.cam.currentFPS.toString());
				log("Camera: FPS: " + this.cam.fps.toString());
				log("Camera: Keyframe Interval: " + this.cam.keyFrameInterval.toString());
				log("Camera: Quality: " + this.cam.quality.toString());

				ExternalInterface.call("FC_onShow");
			} else {
				log("You don't have a camera!");
			}
		}

		private function configureH264():H264VideoStreamSettings
		{
			log("Init H264 encoder");

			var h264:H264VideoStreamSettings = new H264VideoStreamSettings();
			
			h264.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3);
			h264.setKeyFrameInterval(15);
			h264.setQuality(0, 90);
			h264.setMode(this.video.videoWidth, this.video.videoHeight, -1);

			log("h264Settings: Video codec used for compression: " + h264.codec);
			log("h264Settings: Level used for H.264/AVC encoding: " + h264.level);
			log("h264Settings: Profile used for H.264/AVC encoding: " + h264.profile);
			log("h264Settings: Bandwidth: " + h264.bandwidth.toString());
			log("h264Settings: FPS: " + h264.fps.toString());
			log("h264Settings: Keyframe interval: " + h264.keyFrameInterval.toString());
			log("h264Settings: Quality: " + h264.quality.toString());

			return h264;
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
			trace(event.code);
			log(event.code);

			if (event.code == "Camera.Muted")
			{
				showError(4, "Access to the webcam was denied");
				return;
			} else {
				ExternalInterface.call("FC_onWebcamReady");
			}
		}
		
		private function netStatusHandler(event:NetStatusEvent):void
		{
			trace(event.info.code);
			var info:* = event.info;

			switch(info.code)
			{
				case "NetConnection.Connect.Success":
				{
					log("NetConnection connected with protocol " + this.connection.protocol + ", proxy type " + this.connection.proxyType + ", connected proxy type " + this.connection.connectedProxyType);
					ExternalInterface.call("FC_onConnect");
					break;
				}
				case "NetConnection.Connect.Closed":
				{
					ExternalInterface.call("FC_onDisconnect");
					break;
				}
				case "NetConnection.Connect.Failed":
				{
					showError(8, "Could not connect to server, check your firewall");
					break;
				}
				case "NetConnection.Connect.Rejected":
				{
					showError(1, "Unkown connection error");
					break;
				}
				case "NetStream.Play.StreamNotFound":
				{
					showError(10, "The videostream was not found");
					break;
				}
				default:
				{
					break;
				}
			}
		}

		// When streaming video or doing playback using netstream you always have to setup onMetaData
		// so this is used for both AUDIO and VIDEO
		// Where we set the netstream's client to this, it allows the netstream to automatically call this function
		public function onMetaData(info:Object):void
		{
			trace("playback called onMetaData");
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

		private function getFileName():String
		{
			if (!this.fileName) this.fileName = randomNumber().toString();
			return this.fileName;
		}

		// video streaming
		public function recordStart():void
		{
			if (!this.connection.connected)
			{
				showError(12, "Not connected to the server");
			}

			if (this.alreadyRecorded)
			{
				showError(7, "Already recorded this file");
			} else {
				this.alreadyRecorded = true;
				this.stream = new NetStream(this.connection);
				this.stream.addEventListener(NetStatusEvent.NET_STATUS, this.netStatusHandler);
				this.stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, this.netAsyncErrorEvent);
				this.stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.netSecurityErrorEvent);
				this.stream.client = this;

				if (this.useH264) this.stream.videoStreamSettings = this.h264Settings;

				this.stream.attachAudio(this.mic);
				this.stream.attachCamera(this.cam);
				this.stream.publish(this.getFileName(), "record");

				this.video.attachCamera(this.cam);
				log("Record using codec: " + this.stream.videoStreamSettings.codec);
			}
		}
		public function recordStop():void
		{
			this.stream.close();
			this.video.attachCamera(null);
		}

		public function recordPlayback():void
		{
			this.stream = new NetStream(this.connection);
			this.stream.addEventListener(NetStatusEvent.NET_STATUS, this.netStatusHandler);
			this.stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, this.netAsyncErrorEvent);
			this.stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.netSecurityErrorEvent);
			this.stream.client = this;
			this.stream.videoStreamSettings = this.h264Settings;
			this.stream.play(this.getFileName());

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

		private function randomNumber():Number
		{
			return Math.floor(Math.random() * (9999999 - 1000000)) + 1000000;
		}

		private function netAsyncErrorEvent(event:Event):void
		{
			showError(99, "AsyncErrorEvent: " + event);
			return;
		}

		private function netSecurityErrorEvent(event:Event):void
		{
			showError(99, "netSecurityErrorEvent: " + event);
			return;
		}

		private function netIOErrorEvent(event:Event):void
		{
			showError(99, "netnetIOErrorEvent: " + event);
			return;
		}
	}
}
