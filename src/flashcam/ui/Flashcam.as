package flashcam.ui
{
	// Imports
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;

	//import mx.controls.Alert;
	
	public class Flashcam
	{	
		// server address const
		private var rtmp_server:String = "rtmp://localhost/vod";
		
		// components to show your video
		private var video:Video;
		private var cam:Camera;
		private var mic:Microphone;
		private var stream:NetStream;
		private var connection:NetConnection;

		public function Flashcam()
		{
			log("Flashcam created");
		}
		
		public function initialize():void
		{
			log("Flashcam initialized");

			initializeCamera();
			initializeMicrophone();
			initializeConnection();
		}
		
		private function initializeConnection():void
		{
			connection = new NetConnection();
			connection.addEventListener(NetStatusEvent.NET_STATUS,netStatusHandler);
			connection.connect(rtmp_server);
		}

		private function initializeCamera():void
		{
			video = new Video();
			video.opaqueBackground = true;

			cam = Camera.getCamera();

			if (cam != null)
			{
				cam.addEventListener(StatusEvent.STATUS, statusHandler);
				video.attachCamera(cam);
				
				log("Camera plugged in!");
			} else {
				log("You don't have a camera!");
			}
		}

		private function initializeMicrophone():void
		{
			mic = Microphone.getMicrophone();
			mic.setUseEchoSuppression(true);
			mic.setSilenceLevel(0);

			if (mic != null)
			{
				mic.addEventListener(StatusEvent.STATUS, onMicStatus);

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

		private static function log(text:String):void
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
			log("record: start;");

			stream = new NetStream(connection);
			stream.attachAudio(mic);
			stream.attachCamera(cam);
			stream.publish("test","record");

			video.attachCamera(cam);
		}
		public function recordStop():void
		{
			log("record: stop;");

			stream.close();
			video.attachCamera(null);
		}
		public function recordPlay():void
		{
			log("record: play;");

			stream.play("test");
			video.attachNetStream(stream);
		}

		public function getVideo():Video
		{
			return video;
		}
	}
}