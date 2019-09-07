package
{
	import fl.controls.Button;
	import fl.controls.CheckBox;
	import fl.core.UIComponent;
	import fl.events.SliderEvent;
	
	import flash.desktop.NativeApplication;
	import flash.display.Sprite;
	import flash.display.StageQuality;
	import flash.events.Event;
	import flash.events.FileListEvent;
	import flash.events.MouseEvent;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.net.SharedObject;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.system.Capabilities;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	
	[SWF(frameRate="230",height="370",width="310")]
	/**
	 * atfTool 一个批量转换atf格式的工具
	 * @author 游剑峰 QQ:547243998
	 * @langversion 3.0
	 * @playerversion AIR 3.4
	 */	
	public class atfTool extends Sprite
	{
		/** ui */
		public var ui:UI;
		/** 目标路径 */
		private var targetFile:File;
		/** 导出路径 */
		private var exportFile:File;
		/** 要转换的文件 */
		private var fileList:Array;
		/** 是否开始转换 */
		private var isStart:Boolean;
		/** 转换队列 */
		private var queue:Array;
		/** 正在转换的 */
		private var currentFile:File;
		/** 零时目录 */
		private var tempFile:File;
		
		
		private var encodingWorkerRoot:Sprite;
		private var worker:Worker; 
		private var send:MessageChannel;
		private var read:MessageChannel;
		public function atfTool()
		{
			if(Worker.current.isPrimordial){
				toBadyoo();
				platform();
				init();
				encodingWorkerInit();
			}else {
				encodingWorkerRoot=new EncodingWorker();
			}
		}
		/** 首次打开软件跳转到首页 */
		private function toBadyoo():void{
			
		}
		/** 编码线程初始化 */
		private function encodingWorkerInit():void{
			worker=WorkerDomain.current.createWorker(this.loaderInfo.bytes,true);
			read=worker.createMessageChannel(Worker.current);
			send=Worker.current.createMessageChannel(worker);
			Worker.current.setSharedProperty("read",send);
			Worker.current.setSharedProperty("send",read);
			read.addEventListener(Event.CHANNEL_MESSAGE,encodingWorkerMessage);
			worker.start()	
		}
		/** 初始化 */
		private function init():void{
			ui=new UI();
			targetFile=new File();//目标位置
			exportFile=new File();//导出位置
			queue=new Array();//转换队列
			ui.btn_target.addEventListener(MouseEvent.CLICK,UrlClick);
			ui.btn_export.addEventListener(MouseEvent.CLICK,UrlClick);
			ui.start.addEventListener(MouseEvent.CLICK,startSwitch);
			targetFile.addEventListener(FileListEvent.SELECT_MULTIPLE,targetFileSelect);
			exportFile.addEventListener(Event.SELECT,targetFileSelect);
			ui.select_ios.addEventListener(Event.CHANGE,label_change);
			ui.select_android.addEventListener(Event.CHANGE,label_change);
			ui.select_pc.addEventListener(Event.CHANGE,label_change);
			ui.select_all.addEventListener(Event.CHANGE,label_change);
			ui.slider_quality.addEventListener(SliderEvent.THUMB_DRAG,slider_qualityMove);
			ui.select_dragonBones.addEventListener(Event.CHANGE,label_change);
			this.addEventListener(Event.ENTER_FRAME,frame);
			this.addChild(ui);
			NativeApplication.nativeApplication.addEventListener(Event.EXITING,exit);
			showtext(
				"I ATF Tool ver 4.1 \n"+
				"作者：badyoo QQ:547243998\n " +
				"新功能:\n"+
				"支持atf包含xml\n"+
				"支持dragonBones 导出的png（包含xml）\n"+
				"功能:\n"+
				"使用是adobe atf 编码核心最新版，转换速度是以前的编码5倍\n" +
				"队列式转换到各个平台，以及单个平台的atf压缩纹理\n" +
				"支持多文件选择，文件目录批量转换\n" +
				"支持品质设置，quality越小，品质越高\n" +
				"支持mipmap设置\n" +
				"支持压缩体积，减小文件大小\n" +
				"支持预乘Alpha\n" +
				"图像尺寸自动纠正为2幂\n" +
				"支持jpg png 转换\n" +
				"加入多线程编码\n"
				
			)
		}
		/** 平台判断 */
		private function platform():void{
			if(Capabilities.os.indexOf("Windows")!=-1){
				NativeProcesss.platform="windows.exe";
			}
			if(Capabilities.os.indexOf("Mac")!=-1){
				NativeProcesss.platform="mac";
			}
			if(Capabilities.os.indexOf("Linux")!=-1){
				ui.start.enabled=false ;
				ui.btn_export.enabled=false;
				ui.btn_target.enabled=false;
				showtext("不支持Linux");
			}
		}
		/**
		 * 退出处理 
		 * @param e
		 */
		private function exit(e:Event):void{
			NativeApplication.nativeApplication.removeEventListener(Event.EXITING,exit);
			if(tempFile)tempFile.deleteDirectoryAsync(true);//删除临时文件
		}
		/** 品质设置 */
		private function slider_qualityMove(e:SliderEvent):void{
			ui.qualityTxt.text="quality:"+String(ui.slider_quality.value);	
		}
		/**
		 * 路径按钮处理 
		 * @param e
		 */
		private function UrlClick(e:MouseEvent):void{
			if(e.target==ui.btn_target){
				var fileFilter:FileFilter=new FileFilter("png/jpg","*.png;*.jpg"); targetFile.browseForOpenMultiple("请选择要转换的文件:",[fileFilter]);
			}
			else {
				exportFile.browseForDirectory("请选择要保存的目录:");
			}
		}
		/**
		 * 路径选择处理 
		 * @param e
		 */
		private function targetFileSelect(e:Event):void{
			if(e.target==targetFile){
				fileList=(e as FileListEvent).files;
				ui.targetUrl.text=fileList[0].nativePath+"..."+fileList.length+"个文件";
			}
			else {
				ui.exportUrl.text=exportFile.nativePath;
			}
		}
		/**
		 * 开始转换 
		 * @param e
		 */
		private function startSwitch(e:MouseEvent):void{
			ui.showTxt.text="";
			if(ui.select_batch.selected){
				BathFile(true)
			}else {
				BathFile();
			}
		}
		/**
		 * 根据选择，生成转换队列
		 * @param isBath 是否转换文件夹
		 */
		private function BathFile(isBath:Boolean=false):void{
			queue=fileList.concat();
			if(isBath&&ui.targetUrl.text!=""){
				queue=fileList[0].parent.getDirectoryListing();
			}
			if(!queue){
				showtext("请选择要转换的图片...");
				return;
			}
			if(ui.exportUrl.text==""){
				showtext("请选择导出路径...");
				return;
			}
			setUiEnabled(false);
			next();
		}
		/** 转换下一个 */
		private function next():void{
			if(queue.length>0){
				currentFile=queue.shift();
				if(currentFile.extension =="png"||currentFile.extension =="jpg"||currentFile.extension =="JPG"||currentFile.extension =="PNG"){
					/** 执行特殊纹理处理 */
					send.send({act:"handler",data:{url:NativeProcesss.platform=="mac"?currentFile.url:currentFile.nativePath,
						name:currentFile.name,
						premnitiplyAlpha:ui.select_premnitiplyAlpha.selected?true:false,
						dragonBones:ui.select_dragonBones.selected,
						mergerXml:ui.select_mergerXml.selected
					}});
				}else {
					next();
				}
			}else {
				update();
			}
		}
		/** 执行pngToatf 命令行 */
		private function pngToAtf(data:Object):void{
			var input:String=(data.url!=""?data.url:currentFile.nativePath);
			var fileName:String=currentFile.name.slice(0,currentFile.name.lastIndexOf("."));
			var output:String=exportFile.nativePath+File.separator+fileName+".atf";
			new NativeProcesss(fileName,input,output,this,data.xml);
		}
		/** 编码线程通讯 */
		private function encodingWorkerMessage(e:Event):void{
			var data:Object=read.receive();
			switch(data.act)
			{
				case "showTxt":
				{
					showtext(data.data);
					break;
				}
				case "tempFile":
				{
					tempFile=new File(data.data);
					break;
				}	
				case "EncodingWorkerDone":
				{
					pngToAtf(data.data);
					break;
				}	
				default:
				{
					showtext("错误的命令!");
					break;
				}
			}
		}
		/** 更新转换状态，如果还有文件，那么转换下一个，否则转换完成 */
		public function update():void{
			if(queue.length<1){
				setUiEnabled(true);
				showtext("转换完成!");
				remind();
			}else {
				next();
			}
		}
		
		//ui显示处理
		/** 设置ui是否激活 */ 
		private function setUiEnabled(ver:Boolean):void{
			for(var i:int=0;i<ui.numChildren;i++){
				var uicomponent:UIComponent=ui.getChildAt(i) as UIComponent;
				if(uicomponent){
					if(uicomponent is CheckBox || uicomponent is Button){
						uicomponent.enabled=ver;
					}
				}
			}
		}
		/**
		 * 改变选择
		 * @param e
		 */
		private function label_change(e:Event):void{
			switch(e.target)
			{
				case ui.select_ios:
				{
					if(ui.select_ios.selected){
						ui.select_android.selected=false;
						ui.select_pc.selected=false;
						ui.select_all.selected=false;
					}
					break;
				}
				case ui.select_android:
				{
					if(ui.select_android.selected){
						ui.select_ios.selected=false;
						ui.select_pc.selected=false;
						ui.select_all.selected=false;
					}
					break;
				}
				case ui.select_pc:
				{
					if(ui.select_pc.selected){
						ui.select_ios.selected=false;
						ui.select_android.selected=false;
						ui.select_all.selected=false;
					}
					break;
				}
				case ui.select_dragonBones:
				{
					ui.select_mergerXml.selected=true;
					break;
				}  
				default:
				{
					ui.select_pc.selected=false
					ui.select_ios.selected=false;
					ui.select_android.selected=false;
					ui.select_all.selected=true;
					break;
				}
			}
		}
		/** 提醒用户 */
		private function remind():void{
			stage.nativeWindow.activate();
			if(stage.nativeWindow.minimizable)shake(0.02,50);
		}
		/** 显示文本 */
		public function showtext(str:String):void{
			ui.showTxt.text+=str+"\n";
		}
		/** 帧事件 */
		private function frame(e:Event):void{
			shakeUpdate();
		}
		//下面是震动处理
		private var _intensity:Number;//震动强度
		private var _shakeTimer:int;//震动时间
		private var _shakeDecay:Number;//震动衰减时间
		private var isShaking:Boolean;//是否开启震动
		/**
		 * 屏幕晃动 
		 * @param aIntensity 晃动强度
		 * @param aShakeTimer 晃动时间
		 */		
		public function shake( aIntensity:Number, aShakeTimer:int ):void
		{
			_intensity = aIntensity;
			_shakeTimer = aShakeTimer;
			_shakeDecay = aIntensity/aShakeTimer;
			
			isShaking = true;
		}
		/**
		 * 晃动特效 
		 */		
		private function shakeUpdate():void{
			if( isShaking ){
				if( _shakeTimer > 0 )	{
					_shakeTimer --;
					if( _shakeTimer <= 0 )
					{
						_shakeTimer = 0;
						isShaking = false;
					}
					else
					{
						_intensity -= _shakeDecay;
						var tw:Number =stage.nativeWindow.x+stage.nativeWindow.width;
						var th:Number =stage.nativeWindow.y+stage.nativeWindow.height;
						
						var tmpx:Number = Math.random() * _intensity * tw * 2 - _intensity * tw;
						var tmpy:Number = Math.random() * _intensity * th * 2 - _intensity * th;
						
						stage.nativeWindow.x+=tmpx;
						stage.nativeWindow.y+=tmpy;
					}
				}
			}
		}
	}
}