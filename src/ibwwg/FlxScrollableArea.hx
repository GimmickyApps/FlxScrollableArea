package ibwwg;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import ibwwg.FlxScrollbar.FlxScrollbarOrientation;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import openfl.geom.Rectangle;

/**
 * An area of the screen that has automatic scrollbars, if needed.
 * @author In the Beginning was the Word Game
 */
class FlxScrollableArea extends FlxCamera
{
	/**
	 * If your viewing area changes (perhaps in your state's onResize function) you need to update this to reflect it.
	 */
	public var viewPort(default, set):FlxRect;
	/**
	 * If your content's area changes (e.g. the content itself changes, or you override onResize), you need to update this to reflect it.
	 */
	public var content(default, set):FlxRect;
	/**
	 * Returns the best layout strategy you should use in your state's onResize function.  If you passed NONE in the constructor,
	 * this function just returns that.
	 * 
	 * Be sure to resize the viewport before calling this function, which will trigger a recalculation of this value and the scrollbar sizes.
	 * 
	 * For example, you may normally want to FIT_WIDTH, so you pass that into the constructor.  But, at a certain resize ratio with a
	 * certain content aspect ratio, there will be a conflict between this goal and whether there should be a scrollbar.  I.e., if your
	 * content is resized to fit the width of the viewport, it will be too long and require a scrollbar.  But, if you resize it to allow for
	 * a scrollbar, it will then be short enough not to need a scrollbar anymore.  In this case, .bestMode will tell you that you should
	 * instead FIT_HEIGHT, so that, gracefully, you have no scrollbar, but still make things as big as possible.  I.e., your content will
	 * take up part of what a scrollbar would have.
	 * 
	 * Remember to also take into account the scrollbar thickness using horizontalScrollbarHeight and/or verticalScrollbarWidth.
	 */
	public var bestMode(get, null):ResizeMode;
	
	public var horizontalScrollbarHeight(get, null):Int;
	public var verticalScrollbarWidth(get, null):Int;

	#if !FLX_NO_MOUSE
	public var scrollbarThickness:Int = 20;
	#else
	public var scrollbarThickness:Int = 4;
	#end
	private var _state:FlxState;
	private var _horizontalScrollbar:FlxScrollbar;
	private var _verticalScrollbar:FlxScrollbar;
	private var _scrollbarColour:FlxColor;
	private var _resizeModeGoal:ResizeMode;
	private var _hiddenPixelAllowance:Float = 1.0; // don't bother showing scrollbars if this many pixels would go out of view (float weirdness fix)
	/**
	 * Creates a specialized FlxCamera that can be added to FlxG.cameras.
	 *
	 * @param	ViewPort			The area on the screen, in absolute pixels, that will show content.
	 * @param	Content				The area (probably off-screen) to be viewed in ViewPort.  Must have a non-zero width and height.
	 * @param	Mode				State the goal of your own resizing code, so that the .bestMode property contains an accurate value.
	 * @param	ScrollbarThickness	Defaults to 20 for mice and 4 "otherwise" (touch is assumed.)
	 * @param	ScrollbarColour		Passed to FlxScrollbar.  ("They say geniuses pick green," so don't change the default unless you're the supergenius we all know you to be.)
	 * @param	State				Which state to add the scrollbar(s) to.  If you're in a FlxSubState with its parent paused, pass it in here.
	 */
	public function new(ViewPort:FlxRect, Content:FlxRect, Mode:ResizeMode, ?ScrollbarThickness:Int=-1, ?ScrollbarColour:FlxColor=FlxColor.LIME, ?State:FlxState) {
		super();
		
		_state = State;
		if (_state == null)
			_state = FlxG.state;
		content = Content;
		_resizeModeGoal = Mode; // must be before we set the viewport, because set_viewport uses it; likewise next line
		if (ScrollbarThickness > -1)
			scrollbarThickness = ScrollbarThickness;
		viewPort = ViewPort;
		_scrollbarColour = ScrollbarColour;

		scroll.x = content.x;
		scroll.y = content.y;
		
		_verticalScrollbar = new FlxScrollbar( 0, 0, scrollbarThickness, 1, FlxScrollbarOrientation.VERTICAL, ScrollbarColour, this, false, _state );
		_state.add( _verticalScrollbar );
		_horizontalScrollbar = new FlxScrollbar( 0, 0, 1, scrollbarThickness, FlxScrollbarOrientation.HORIZONTAL, ScrollbarColour, this, false, _state );
		_state.add( _horizontalScrollbar );

		onResize();
	}
	/**
	 * Based on the new viewPort, sets bestMode, horizontalScrollbarHeight, and verticalScrollbarWidth.
	 * 
	 * @param	value	The new viewPort.
	 * @return			The same as you passed in, for assignment chaining.
	 */
	function set_viewPort(value:FlxRect):FlxRect 
	{
		verticalScrollbarWidth = 0;
		horizontalScrollbarHeight = 0; // until otherwise calculated

		#if !FLX_NO_MOUSE
			if (_resizeModeGoal == NONE) { // base it directly on content, since this is only used from onResize
				bestMode = NONE;
				if (content.width - value.width > _hiddenPixelAllowance) {
					horizontalScrollbarHeight = scrollbarThickness;
				}
				if (content.height - (value.height - horizontalScrollbarHeight) > _hiddenPixelAllowance) {
					verticalScrollbarWidth = scrollbarThickness;
					// now, with less width available, do we still fit?
					if (content.width - (value.width - verticalScrollbarWidth) > _hiddenPixelAllowance) {
						horizontalScrollbarHeight = scrollbarThickness;
					}
				}
			} else {
				// base it on the ratio only, because this will be used outside the class to determine new content size
				var contentRatio = content.width / content.height;
				var viewPortRatio = value.width / value.height;
				if (_resizeModeGoal == FIT_HEIGHT) {
					if (viewPortRatio >= contentRatio) {
						bestMode = FIT_HEIGHT;
						horizontalScrollbarHeight = 0;
					} else {
						var scrollbarredContentRatio = content.width / (content.height + scrollbarThickness);
						if (viewPortRatio <= scrollbarredContentRatio) {
							bestMode = FIT_HEIGHT;
							horizontalScrollbarHeight = scrollbarThickness;
						} else { // in the twilight zone
							bestMode = FIT_WIDTH;
							horizontalScrollbarHeight = 0;
						}
					}
				} else { // FIT_WIDTH
					if (viewPortRatio <= contentRatio) {
						bestMode = FIT_WIDTH;
						verticalScrollbarWidth = 0;
					} else {
						var scrollbarredContentRatio = (content.width + scrollbarThickness) / content.height;
						if (viewPortRatio >= scrollbarredContentRatio) {
							bestMode = FIT_WIDTH;
							verticalScrollbarWidth = scrollbarThickness;
						} else { // in the twilight zone
							bestMode = FIT_HEIGHT;
							verticalScrollbarWidth = 0;
						}
					}				
				}
			}
		#end
		return viewPort = value;
	}
	/**
	 * Assumes that .viewPort has already been set in the parent state's onResize function.
	 * 
	 * This is automatically re-run the moment .visible is set to true, to make sure that the correct scrollbars are visible.
	 * 
	 * During resizing, this is skipped if .visible is false.
	 */
	override public function onResize() {
		if (!visible)
			return;
		super.onResize();

		#if !FLX_NO_MOUSE
			if (verticalScrollbarWidth > 0) {
				_verticalScrollbar.visible = true;
				if (horizontalScrollbarHeight > 0) { // both
					_horizontalScrollbar.visible = true;
					_horizontalScrollbar.width = viewPort.width - verticalScrollbarWidth;
					_verticalScrollbar.height = viewPort.height - horizontalScrollbarHeight;
				} else { // just vert
					_horizontalScrollbar.visible = false;
					_verticalScrollbar.height = viewPort.height;
				}
			} else {
				_verticalScrollbar.visible = false;
				if (horizontalScrollbarHeight > 0) { // just horiz
					_horizontalScrollbar.visible = true;
					_horizontalScrollbar.width = viewPort.width;
				} else { // neither
					_horizontalScrollbar.visible = false;
				}
			}
			if (_verticalScrollbar.visible) {
				_verticalScrollbar.x = viewPort.right - scrollbarThickness;
				_verticalScrollbar.y = viewPort.y;
			}
			if (_horizontalScrollbar.visible) {
				_horizontalScrollbar.x = viewPort.x;
				_horizontalScrollbar.y = viewPort.bottom - scrollbarThickness;
			}
			if (_verticalScrollbar.visible || _horizontalScrollbar.visible) {
				_verticalScrollbar.updateViewScroll();
				_horizontalScrollbar.updateViewScroll();
			}
			if (_verticalScrollbar.visible)
				_verticalScrollbar.draw();
			if (_horizontalScrollbar.visible)
				_horizontalScrollbar.draw();
		#end
		x = Std.int( viewPort.x );
		y = Std.int( viewPort.y );
		width = Std.int( viewPort.width - verticalScrollbarWidth );
		height = Std.int( viewPort.height - horizontalScrollbarHeight );
	}
	function get_bestMode():ResizeMode 
	{
		return bestMode;
	}
	function get_horizontalScrollbarHeight():Int 
	{
		return horizontalScrollbarHeight;
	}
	function get_verticalScrollbarWidth():Int 
	{
		return verticalScrollbarWidth;
	}
	override public function set_visible(value:Bool):Bool {
		super.set_visible(value); // so onResize doesn't return early
		if (value) // if visible
			onResize(); // show only if needed (recalc)
		else
			_horizontalScrollbar.visible = _verticalScrollbar.visible = false; // don't show
		return value;
	}
	override public function destroy() {
		for (bar in [_horizontalScrollbar, _verticalScrollbar]) {
			_state.remove(bar);
			bar.destroy();
		}
		super.destroy();
	}
	
	function set_content(value:FlxRect):FlxRect 
	{
		content = value;
		if (viewPort != null) // not during the constructor, but normally...
			set_viewPort( viewPort ); // ...force update
		return content;
	}
}
enum ResizeMode {
	FIT_WIDTH;
	FIT_HEIGHT;
	NONE;
}