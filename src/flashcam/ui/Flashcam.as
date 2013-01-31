package flashcam.ui
{
	// Imports
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.NetConnection;
	// import mx.controls.Alert;
	
	public class Flashcam
	{	
		// server address const
		private var rtmp_server:String = "rtmp://localhost/vod";
		
		// components to show your video
		public var video:Video;

		private var cam:Camera;
		private var nc:NetConnection;

		public function Flashcam()
		{
			log("Flashcam created");
		}
		
		public function initialize():void
		{
			log("Flashcam initialized");
						
			video = new Video();
			video.opaqueBackground = true;
			
			cam = Camera.getCamera();
			
			initializeConnection();
		}
		
		public function initializeConnection():void
		{
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS,netStatusHandler);
			nc.connect(rtmp_server);			
		}

		public function initializeCamera(event:Event):void
		{
			if (cam != null)
			{
				cam.addEventListener(StatusEvent.STATUS, statusHandler);
				video.attachCamera(cam);
				
				log("Camera plugged in!");
			} else {
				log("You don't have a camera!");
			}
		}
		
		public function statusHandler(event:StatusEvent):void
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
		
		private static function log(text: String):void
		{
			if (ExternalInterface.available) {
				ExternalInterface.call("console.log", text);
				// mx.controls.Alert.show(text);
			}
			return;
		}
	}
}