package
{
	import flash.desktop.NativeApplication;
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.getTimer;

	/**
	 * NativeProcesss 运行本地转换程序的接口
	 * @author 游剑峰 QQ:547243998
	 * @langversion 3.0
	 * @playerversion AIR 3.4
	 */
	public class NativeProcesss
	{
		public static var platform:String;
		private var fileName:String;
		private var nativeProcess:NativeProcess=new NativeProcess();
		private var root:atfTool;
		private var mess:String="";
		private var xml:String="";
		private var output:String="";
		private var files:FileStream=new FileStream();
		public function NativeProcesss(fileName:String,input:String,output:String,root:atfTool,xml:String="")
		{
			this.fileName=fileName;
			this.mess=fileName;
			this.xml=xml;
			this.output=output;
			this.root=root;
			var args:Vector.<String>=new Vector.<String>();
			args.push("-i",input,"-o",output,"-q",root.ui.slider_quality.value);
			if(!root.ui.select_mipmap.selected)args.push("-n","0,0");
			args.push('-c',root.ui.select_all.selected?"":root.ui.select_android.selected ? "e":root.ui.select_ios.selected?"p":"d");
			if(root.ui.select_compress.selected)args.push("-r");
			args.push("-4");
			var info:NativeProcessStartupInfo=new NativeProcessStartupInfo();
			info.arguments=args;
			info.executable=File.applicationDirectory.resolvePath(platform);
			nativeProcess.start(info);
			files.addEventListener(Event.COMPLETE,filesComplete);
			files.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS,output_progress);
			NativeApplication.nativeApplication.addEventListener(Event.EXITING,exit);
			nativeProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,nativeProcessOutput_data);
			nativeProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA,nativeProcessError_data);
			root.showtext("正在转换:"+fileName);
		}
		/**
		 * 退出处理 
		 * @param e
		 */
		private function exit(e:Event):void{
			trace("NativeProcesss",fileName,"exit!")
			dispose();
		}
		/**
		 * 转换器的错误输出 
		 * @param e
		 */
		private function nativeProcessError_data(e:ProgressEvent):void{
			root.showtext(fileName+" 转换失败!原因:"+nativeProcess.standardError.readMultiByte(nativeProcess.standardError.bytesAvailable,"cn-gb"));
			dispose();
			root=null;
		}
		/**
		 * 转换器的输出
		 * @param e
		 */
		private function nativeProcessOutput_data(e:ProgressEvent):void{
			mess+=nativeProcess.standardOutput.readMultiByte(nativeProcess.standardOutput.bytesAvailable,"cn-gb");
			if(mess.indexOf("[Ratio")!=-1){
				mess=fileName+" 转换成功!";
				if(xml){
					files.openAsync(new File(output),FileMode.UPDATE);
				}else {
					clear()	
				}
			}else {
				root.showtext(mess);
			}
		}
		private function filesComplete(e:Event):void{
			files.removeEventListener(Event.COMPLETE,filesComplete);
			var size:uint=files.bytesAvailable;
			files.position=size;
			files.writeUTFBytes(xml);
			files.writeInt(size);
		}
		private function output_progress(e:OutputProgressEvent):void{
			if(e.bytesPending==0){
				root.showtext("[合并配置完成]")
				files.removeEventListener(OutputProgressEvent.OUTPUT_PROGRESS,output_progress);
				files.close();
				files=null;
				clear();
			}
		}
		/** 清除引用*/
		private function clear():void{
			dispose();
			root.showtext(mess);
			root.update();
			root=null;
		}
		private function dispose():void{
			nativeProcess.exit(true);
			NativeApplication.nativeApplication.removeEventListener(Event.EXITING,exit);
			nativeProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,nativeProcessOutput_data);
			nativeProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA,nativeProcessError_data);
			nativeProcess=null;
		}
	}
}