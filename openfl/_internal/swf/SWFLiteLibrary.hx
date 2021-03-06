package openfl._internal.swf;


import haxe.Unserializer;
import lime.app.Future;
import lime.app.Promise;
import lime.graphics.Image;
import lime.graphics.ImageChannel;
import lime.math.Vector2;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets in LimeAssets;
import openfl._internal.swf.SWFLite;
import openfl._internal.symbols.BitmapSymbol;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.display.MovieClip;
import openfl.events.Event;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.ByteArray;
import openfl.Assets;


@:keep class SWFLiteLibrary extends AssetLibrary {
	
	
	private var alphaCheck:Map<String, Bool>;
	private var id:String;
	private var preloading:Bool;
	private var rootPath:String;
	private var swf:SWFLite;
	
	
	public function new (id:String) {
		
		super ();
		
		this.id = id;
		
		alphaCheck = new Map ();
		
		#if (ios || tvos)
		rootPath = "assets/";
		#else
		rootPath = "";
		#end
		
		// Hack to include filter classes, macro.include is not working properly
		
		//var filter = flash.filters.BlurFilter;
		//var filter = flash.filters.DropShadowFilter;
		//var filter = flash.filters.GlowFilter;
		
	}
	
	
	public override function exists (id:String, type:String):Bool {
		
		if (swf == null) return false;
		
		if (id == "" && type == (cast AssetType.MOVIE_CLIP)) {
			
			return true;
			
		}
		
		if (type == (cast AssetType.IMAGE) || type == (cast AssetType.MOVIE_CLIP)) {
			
			return (swf != null && swf.hasSymbol (id));
			
		}
		
		return false;
		
	}
	
	
	public override function getImage (id:String):Image {
		
		// TODO: Better system?
		
		if (!alphaCheck.exists (id)) {
			
			for (symbol in swf.symbols) {
				
				if (Std.is (symbol, BitmapSymbol) && cast (symbol, BitmapSymbol).path == id) {
					
					var bitmapSymbol:BitmapSymbol = cast symbol;
					
					if (bitmapSymbol.alpha != null) {
						
						var image = super.getImage (id);
						var alpha = super.getImage (bitmapSymbol.alpha);
						
						__copyChannel (image, alpha);
						
						cachedImages.set (id, image);
						alphaCheck.set (id, true);
						
						return image;
						
					}
					
				}
				
			}
			
		}
		
		return super.getImage (id);
		
	}
	
	
	public override function getMovieClip (id:String):MovieClip {
		
		return (swf != null) ? swf.createMovieClip (id) : null;
		
	}
	
	
	public override function isLocal (id:String, type:String):Bool {
		
		return true;
		
	}
	
	
	public override function load ():Future<lime.utils.AssetLibrary> {
		
		if (id != null) {
			
			preload.set (id, true);
			
		}
		
		#if (js && html5)
		for (id in paths.keys ()) {
			
			preload.set (id, true);
			
		}
		#end
		
		var promise = new Promise<lime.utils.AssetLibrary> ();
		preloading = true;
		
		loadText (id).onError (promise.error).onComplete (function (data) {
			
			swf = SWFLite.unserialize (data);
			swf.library = this;
			
			SWFLite.instances.set (id, swf);
			
			__load ().onProgress (promise.progress).onError (promise.error).onComplete (function (_) {
				
				preloading = false;
				promise.complete (this);
				
			});
			
		});
		
		return promise.future;
		
	}
	
	
	public override function loadImage (id:String):Future<Image> {
		
		// TODO: Better system?
		
		if (#if (swf_preload || swflite_preload) true #else !preloading #end && !alphaCheck.exists (id)) {
			
			for (symbol in swf.symbols) {
				
				if (Std.is (symbol, BitmapSymbol) && cast (symbol, BitmapSymbol).path == id) {
					
					var bitmapSymbol:BitmapSymbol = cast symbol;
					
					if (bitmapSymbol.alpha != null) {
						
						var promise = new Promise<Image> ();
						
						__loadImage (id).onError (promise.error).onComplete (function (image) {
							
							__loadImage (bitmapSymbol.alpha).onError (promise.error).onComplete (function (alpha) {
								
								__copyChannel (image, alpha);
								
								cachedImages.set (id, image);
								alphaCheck.set (id, true);
								
								promise.complete (image);
								
							});
							
						});
						
						return promise.future;
						
					}
					
				}
				
			}
			
		}
		
		return super.loadImage (id);
		
	}
	
	
	public override function unload ():Void {
		
		var bitmap:BitmapSymbol;
		
		for (symbol in swf.symbols) {
			
			if (Std.is (symbol, BitmapSymbol)) {
				
				bitmap = cast symbol;
				Assets.cache.removeBitmapData (bitmap.path);
				
			}
			
		}
		
	}
	
	
	private function __copyChannel (image:Image, alpha:Image):Void {
		
		if (alpha != null) {
			
			image.copyChannel (alpha, alpha.rect, new Vector2 (), ImageChannel.RED, ImageChannel.ALPHA);
			
		}
		
		image.buffer.premultiplied = true;
		
		#if !sys
		image.premultiplied = false;
		#end
		
	}
	
	
	private function __load ():Future<lime.utils.AssetLibrary> {
		
		return super.load ();
		
	}
	
	
	private function __loadImage (id:String):Future<Image> {
		
		return super.loadImage (id);
		
	}
	
	
}