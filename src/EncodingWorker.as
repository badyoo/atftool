package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.PNGEncoderOptions;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Point;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.utils.ByteArray;
	
	/**
	 * EncodingWorker 编码的工人线程
	 * @author 游剑峰 QQ:547243998
	 * @langversion 3.0
	 * @playerversion AIR 3.4
	 */
	public class EncodingWorker extends Sprite
	{
		private var xml:String;
		private var loader:Loader=new Loader();
		private var currentData:Object;
		private var currentBitmap:Bitmap;
		private var tempFile:File;
		private var tempFileStream:FileStream;
		private var rootWorker:Worker;
		private var send:MessageChannel;
		private var read:MessageChannel;
		public function EncodingWorker()
		{
			tempFile=File.createTempDirectory();
			tempFileStream=new FileStream();
			for(var i:int=0;i<WorkerDomain.current.listWorkers().length;i++){
				if(WorkerDomain.current.listWorkers()[i].isPrimordial){
					rootWorker=WorkerDomain.current.listWorkers()[i];
					send=rootWorker.getSharedProperty("send");
					read=rootWorker.getSharedProperty("read");
					send.send({act:"tempFile",data:tempFile.nativePath});
					read.addEventListener(Event.CHANNEL_MESSAGE,encodingWorkerMessage);
				}
			}
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE,loaderLoadDone);
			loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,error);
		}
		private function showTxt(str:String):void{
			send.send({act:"showTxt",data:str});
		}
		private function encodingWorkerMessage(e:Event):void{
			var data:Object=read.receive();
			switch(data.act)
			{
				case "handler":
				{
					loaderImage(data.data);
					break;
				}
				default:
				{
					send.send({act:"错误的命令"});
					break;
				}
			}
		}
		private function loaderImage(data:Object):void{
			showTxt("正在加载需要处理的图像...");
			currentData=data;
			loader.load(new URLRequest(currentData.url));
		}
		private function loaderLoadDone(e:Event):void{
			showTxt("图像加载完成,开始处理...");
			currentBitmap=loader.content as Bitmap;
			if(currentData.mergerXml||currentData.dragonBones){
				mergerXmlHandler();
			}else {
				imageHandler();
			}
		}
		private function error(e:Event):void{
			showTxt(currentData.url+"图像加载失败");
		}
		private function mergerXmlHandler():void{
			var url:String;
			var urlLoader:URLLoader=new URLLoader();
			if(currentData.dragonBones){
				urlLoader.dataFormat=URLLoaderDataFormat.BINARY;
				showTxt("[dragonBones]开始解析骨骼配置文件");
				url=currentData.url;
			}else {
				showTxt("[合并配置],开始处理配置文件");
				var fileUrl:String=currentData.url.slice(0,currentData.url.lastIndexOf("."));
				url=fileUrl+".xml";
			}
			
			urlLoader.addEventListener(Event.COMPLETE,xmlLoadDone);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR,xmlLoadError);
			urlLoader.load(new URLRequest(url))
			if(currentData.dragonBones){
				showTxt("[dragonBones],加载dragonBones文件"+url);
			}else {
				showTxt("[合并配置],加载配置文件"+url);
			}
		}
		private function xmlLoadDone(e:Event):void{
			if(currentData.dragonBones){
				showTxt("[dragonBones],dragonBones文件加载成功");	
				var compressedByteArray:ByteArray=(e.currentTarget as URLLoader).data ;
				compressedByteArray.position = compressedByteArray.length - 4;
				var strSize:int = compressedByteArray.readInt();
				var position:uint = compressedByteArray.length - 4 - strSize;
				var xmlBytes:ByteArray = new ByteArray();
				xmlBytes.writeBytes(compressedByteArray, position, strSize);
				xmlBytes.uncompress();
				compressedByteArray.length = position;		
				var skeletonXML:XML = XML(xmlBytes.readUTFBytes(xmlBytes.length));	
				compressedByteArray.position = compressedByteArray.length - 4;
				strSize = compressedByteArray.readInt();
				position = compressedByteArray.length - 4 - strSize;	
				xmlBytes.length = 0;
				xmlBytes.writeBytes(compressedByteArray, position, strSize);
				xmlBytes.uncompress();
				compressedByteArray.length = position;
				var textureAtlasXML:XML = XML(xmlBytes.readUTFBytes(xmlBytes.length));
				textureAtlasXML.skeletonXML=skeletonXML;
				xml=textureAtlasXML.toString();
				
			}else{
				
				showTxt("[合并配置],配置文件加载成功");
				xml=(e.currentTarget as URLLoader).data ;
			}
			e.currentTarget.removeEventListener(Event.COMPLETE,xmlLoadDone);
			e.currentTarget.removeEventListener(IOErrorEvent.IO_ERROR,xmlLoadError);
			e.currentTarget.close()
			imageHandler();
		}
		private function xmlLoadError(e:IOErrorEvent):void{
			showTxt("[合并配置],配置文件加载失败，请确定配置文件是否跟"+currentData.url+"同一个目录");
		}
		private function imageHandler():void{
			var origWidth:int   = currentBitmap.bitmapData.width;
			var origHeight:int  = currentBitmap.bitmapData.height;
			var legalWidth:int  = getNextPowerOfTwo(origWidth);
			var legalHeight:int = getNextPowerOfTwo(origHeight);
			var bitmapdata:BitmapData=currentBitmap.bitmapData;
			if (legalWidth > origWidth || legalHeight > origHeight)
			{
				showTxt("纹理尺寸不对，自动处理纹理尺寸为 PowerOfTwo...");
				bitmapdata = new BitmapData(legalWidth, legalHeight, true, 0);
				bitmapdata.copyPixels(currentBitmap.bitmapData, currentBitmap.bitmapData.rect, new Point(0, 0));
				showTxt("纹理尺寸处理完成！");
			}
			if(currentData.premnitiplyAlpha){
				showTxt("纹理 premnitiplyAlpha 处理...");
				bitmapdata=Color.premnitiplyAlphaDispose(bitmapdata);
				showTxt("纹理 premnitiplyAlpha 处理完成！");
			}
			saveTemp(bitmapdata);
		}
		private function saveTemp(bitmapdata:BitmapData):void{
			var byte:ByteArray=new ByteArray();
			showTxt("正在编码并保存零时文件！");
			bitmapdata.encode(bitmapdata.rect,new PNGEncoderOptions,byte);
			var file:File=new File(tempFile.resolvePath(currentData.name).nativePath);
			tempFileStream.open(file,FileMode.WRITE);
			tempFileStream.writeBytes(byte);
			tempFileStream.close();
			if(bitmapdata)bitmapdata.dispose();bitmapdata=null;
			if(currentBitmap&&currentBitmap.bitmapData)currentBitmap.bitmapData.dispose();currentBitmap=null;
			send.send({act:"EncodingWorkerDone",data:{url:file.nativePath,xml:xml}});
		}
	}
}