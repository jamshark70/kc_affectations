// Using Proto and chucklib storage for GUIs
// Transport controls
// James Harkins

// Document.current.autoComplete;

var	savetype = AbstractChuckArray.defaultSubType;

AbstractChuckArray.defaultSubType = \transports;

protect {

// definitions... kind of wordy but you know how it goes
Proto({
	~triangle = { |rect, color, pointsLeft = false|
		var	top = rect.top, bottom = rect.bottom, left, right,
			halfy = (top + bottom) / 2;
		if(pointsLeft) {
			left = rect.right; right = rect.left;
		} {
			left = rect.left; right = rect.right;
		};
		GUI.pen.color_(color)
			.moveTo(left@top)
			.lineTo(right@halfy)
			.lineTo(left@bottom)
			.lineTo(left@top)
			.fill;
	};
	~rightTri = { |rect, color, orientation = \bottomLeft|
		var	pt1, pt2, pt3;
		switch(orientation)
			{ \bottomLeft } {
				pt1 = rect.leftBottom;
				pt2 = rect.leftTop;
				pt3 = rect.rightBottom;
			}
			{ \topLeft } {
				pt1 = rect.leftBottom;
				pt2 = rect.leftTop;
				pt3 = rect.rightTop;
			}
			{ \topRight } {
				pt1 = rect.leftTop;
				pt2 = rect.rightBottom;
				pt3 = rect.rightTop;
			}
			{ \bottomRight } {
				pt1 = rect.leftBottom;
				pt2 = rect.rightBottom;
				pt3 = rect.rightTop;
			};
		GUI.pen.color_(color)
			.moveTo(pt1)
			.lineTo(pt2)
			.lineTo(pt3)
			.lineTo(pt1)
			.fill;
	};		
	~border = { |rect, thickness, outerColor|
		GUI.pen.color_(outerColor)
			.fillRect(Rect(rect.left, rect.top, rect.width, thickness))
			.fillRect(Rect(rect.left, rect.bottom - thickness, rect.width, thickness))
			.fillRect(Rect(rect.left, rect.top, thickness, rect.height))
			.fillRect(Rect(rect.right - thickness, rect.top, thickness, rect.height))
	};
	~border3d = { |rect, thickness, innerColor, leftTopBlend (Color.white), rightBottomBlend (Color.black)|
		var	shaded = innerColor.blend(rightBottomBlend, 0.5);
		GUI.pen.color_(innerColor.blend(leftTopBlend, 0.5))
			.fillRect(Rect(rect.left, rect.top, rect.width, thickness))
			.fillRect(Rect(rect.left, rect.top, thickness, rect.height))
			.color_(shaded)
			.fillRect(Rect(rect.left + thickness, rect.bottom - thickness, rect.width - thickness, thickness))
			.fillRect(Rect(rect.right - thickness, rect.top + thickness, thickness, rect.height - thickness));
		~rightTri.(Rect(rect.left, rect.bottom - thickness, thickness, thickness), shaded, \bottomRight);
		~rightTri.(Rect(rect.right - thickness, rect.top, thickness, thickness), shaded, \bottomRight);
	};
}) => PR(\penUtils);


PR(\penUtils).clone({
	~prep = { |window, bounds, color|
		~bounds = bounds.asRect;
//		~drawBounds = ~bounds.moveBy(window.bounds.left.neg, window.bounds.top.neg);
		~drawBounds = ~bounds.moveTo(0, 0);
		~view = GUI.userView.new(window, bounds)
			/*.relativeOrigin_(false)*/;
		~drawFunc = e(~drawFunc);
		~drawPressedFunc = e(~drawPressedFunc);
		~view.drawFunc_(~drawFunc)
			.canFocus_(false)
			.mouseDownAction_(e { |view|
				if(~enabled) {
					view.drawFunc_(~drawPressedFunc).refresh;
				};
			})
			.mouseUpAction_(e { |view, x, y, modifiers|
				if(~enabled) {
					view.drawFunc_(~drawFunc).refresh;
					if(~mouseCheckBounds.containsPoint(x@y)) {
						~action.(view, x, y, modifiers);
					};
				};
			})
			.refresh;
		~mouseCheckBounds = if(thisProcess.platform.name == \windows)
			{ ~view.bounds } { ~drawBounds };
		// other init?
		currentEnvironment
	};
	~background = Color.gray(0.7);
	~thickness = 2;
	~offset = 2;
	~draw = { |bounds, pressed = false|
		var	leftTopColor, rightBottomColor,
			backColor = if(~enabled) { ~background } { ~background.blend(Color.white, 0.5) };
		if(pressed) {
			leftTopColor = Color.black;
			rightBottomColor = Color.white;
		} {
			leftTopColor = Color.white;
			rightBottomColor = Color.black;
		};
		GUI.pen.color_(backColor)
			.fillRect(~drawBounds);
		~border3d.(~drawBounds, ~thickness, backColor, leftTopColor, rightBottomColor);
		~drawContents.(bounds, pressed);
	};
	~drawContents = { |bounds, pressed|
		var	str = ~string ? "test";
		GUI.pen.color_(Color.black);
		GUI.pen.stringCenteredIn(str, bounds);
	};
	~drawFunc = { |view| ~draw.(~drawBounds) };
		// +1, -1? Jury's out
	~drawPressedFunc = { |view| ~draw.(~drawBounds.moveBy(~offset ? 1, ~offset ? 1), true) };
	~remove = { ~view.remove };
	~enabled = true;
	~enabled_ = { |bool = true|
		~enabled = bool;
		~view.refresh;
	};
}) => PR(\userButton);

PR(\userButton).clone({
	~currentState = 0;
	~playArrowColor = Color.green(0.5);
	~pauseBarColor = Color.gray(0.3);
	~playingBackground = ~background;
	~drawContents = { |bounds, pressed|
		bounds = bounds.insetBy(bounds.width * 0.2, bounds.height * 0.2);
		if(~currentState == 0) {
			~triangle.(bounds, ~playArrowColor);
		} {
			bounds.width = ~view.bounds.width * 0.2;
			GUI.pen.color_(~pauseBarColor)
				.fillRect(bounds)
				.fillRect(bounds.moveBy(bounds.width * 2, 0))
		};
	};
	~action = {
		~currentState = 1 - ~currentState;
		~setBkgdForState.();
		~view.refresh;
		~userAction.(currentEnvironment);
	};
	~currentState_ = { |state|
		~currentState = state;
		~setBkgdForState.();
		~view.refresh;
	};
	~setBkgdForState = {
		if(~showingPlay.()) {
			if(~saveBackground.isNil) {
				~saveBackground = ~background;
			};
			~background = ~playingBackground;
		} {
			if(~saveBackground.notNil) {
				~background = ~saveBackground;
				~saveBackground = nil;
			};
		};
	};
	~showingPlay = { ~currentState > 0 };
}) => PR(\playPauseButton);

PR(\userButton).clone({
	~arrowColor = Color.gray(0.3);
	~drawContents = { |bounds, pressed|
		var	halfwidth, midx,
			arrowColor = if(~enabled) { ~arrowColor } { ~arrowColor.blend(Color.white, 0.5) };
		bounds = bounds.insetBy(bounds.width * 0.2, bounds.height * 0.2);
		halfwidth = bounds.width * 0.5;
		midx = bounds.left + halfwidth;
		~triangle.(bounds.copy.left_(midx).width_(halfwidth), arrowColor, true);
		~triangle.(bounds.copy.width_(halfwidth), arrowColor, true);
		GUI.pen.fillRect(Rect(bounds.left - (halfwidth*0.2), bounds.top, halfwidth*0.2, bounds.height));
	};
}) => PR(\gotoBeginningButton);

PR(\userButton).clone({
	~arrowColor = Color.gray(0.3);
	~drawContents = { |bounds, pressed|
		var arrowColor = if(~enabled) { ~arrowColor } { ~arrowColor.blend(Color.white, 0.5) };
		bounds = bounds.insetBy(bounds.width * 0.2, bounds.height * 0.2);
		~triangle.(bounds, arrowColor, true);
		GUI.pen.fillRect(Rect(bounds.left - (bounds.width*0.1), bounds.top,
			bounds.width*0.1, bounds.height));
	};
}) => PR(\backOneSectionButton);

PR(\userButton).clone({
	~arrowColor = Color.gray(0.3);
	~drawContents = { |bounds, pressed|
		var arrowColor = if(~enabled) { ~arrowColor } { ~arrowColor.blend(Color.white, 0.5) };
		bounds = bounds.insetBy(bounds.width * 0.2, bounds.height * 0.2);
		~triangle.(bounds, arrowColor);
		GUI.pen.fillRect(Rect(bounds.right, bounds.top, bounds.width*0.1, bounds.height));
	};
}) => PR(\fwdOneSectionButton);

PR(\userButton).clone({
	~currentState = false;
	~arrowColor = Color.black;
	~background = Color.white;
	~drawContents = { |bounds|
		var	mid;
		if(~currentState) {
//			bounds = Rect(bounds.left * 0.25, bounds.top * 0.25,
//				bounds.width * 0.25, bounds.height * 0.25);
			bounds = bounds.insetBy(bounds.width * 0.2, bounds.height * 0.2);
			mid = bounds.center;
			GUI.pen
				.moveTo(bounds.rightTop)
				.color_(~arrowColor)
				.width_(min(bounds.height, bounds.width) * 0.25)
				.lineTo(Point(mid.x, bounds.bottom))
				.lineTo(Point(bounds.left, mid.y))
				.stroke
		}
	};
	~action = {
		~currentState = ~currentState.not;
		~view.refresh;
		~userAction.(currentEnvironment);
	};
	~currentState_ = { |value|
		~currentState = value;
		~view.tryPerform(\refresh);
		currentEnvironment
	};
	~isEnabled = { ~currentState };
	~drawPressedFunc = nil;  // ~drawFunc;	// no need to offset for this one
}) => PR(\checkButton);

Proto({
	~background = Color.gray(0.7);
	~color = Color.new255(255, 200, 100);
	~flashBackground = ~background;
	~flashColor = Color.green(0.4);
	~isFlashing = false;
	~isLit = false;
	~visible = true;

	~insetRatio = 0.15;		// 20% of bounds
	~prep = { |parent, bounds|
		~parentView = parent;
		~bounds = bounds.asRect;
		~drawBounds = ~bounds.moveTo(0, 0); //.moveBy(parent.bounds.left.neg, parent.bounds.top.neg);
		~insetRatio_.(~insetRatio);
//		~bounds_.(bounds);
//		~insetX = ~bounds.width * ~insetRatio;
//		~insetY = ~bounds.height * ~insetRatio;
//		~insetBounds = ~bounds.insetBy(~insetX, ~insetY);
		~view = GUI.userView.new(~parentView, ~bounds)
//			.relativeOrigin_(false)
			.canFocus_(false)
			.drawFunc_(e { |view|
				if(~visible) {
					GUI.pen
						.color_(~background)
						.fillRect(~bounds)
						.color_(~color)
						.fillOval(~insetBounds);
				};
			});
		currentEnvironment	// must return myself, not the view
	};
	~remove = {
		~view.remove
	};
	~refresh = {
		(e { ~view.tryPerform(\refresh) }).defer;
	};
	
	~lightOn = {
		if(~isLit.not) {
			~saveBackground = ~background;
			~saveColor = ~color;
			~background = ~flashBackground;
			~color = ~flashColor;
			~refresh.();
			~isLit = true;
		};
	};
	~lightOff = {
		if(~isLit) {
			~background = ~saveBackground;
			~color = ~saveColor;
			~refresh.();
			~isLit = false;
		};
	};
	~flash = { |dur = 0.2|
		if(~isFlashing.not) {
			~lightOn.();
			AppClock.sched(dur, e {
				~lightOff.();
				~refresh.();
				~isFlashing = false;
			});
			~isFlashing = true;
		};
		currentEnvironment
	};
	
	~color_ = { |color|
		if(~isLit) {
			~saveColor = color;		// if flashing, refresh will be coming soon
		} {
			~color = color;
			~refresh.();
		};
		currentEnvironment
	};

	~background_ = { |color|
		if(~isLit) {
			~saveBackground = color;
		} {
			~background = color;
			~refresh.();
		};
		currentEnvironment
	};
	~bounds_ = { |bounds|
		~bounds = bounds.asRect;
		~drawBounds = ~bounds.moveBy(~parentView.bounds.left.neg, ~parentView.bounds.top.neg);
		~insetBounds = ~drawBounds.insetBy(~insetX, ~insetY);
		~view !? { ~view.bounds_(bounds).refresh };
		currentEnvironment
	};
	~insetRatio_ = { |ratio|
		~insetRatio = ratio;
		~drawBounds !? {
			~insetX = ~bounds.width * ~insetRatio;
			~insetY = ~bounds.height * ~insetRatio;
			~insetBounds = ~drawBounds.insetBy(~insetX, ~insetY);
		};
		~view !? { ~view.refresh };
		currentEnvironment
	};
	~visible_ = { |bool = true|
		~visible = bool;
		~refresh.();
		currentEnvironment
	};
}) => PR(\lightView);


Proto({
	~countOffBeats = 4;
//	~drumTempo = 108;
	
//	~bigButtonSize = 293;
	~smallButtonSize = 95;
	~menuHeight = 40;
	~menuFontSpec = ["Lucida Grande Bold", 18];
	~countFontSpec = ["Lucida Grande Bold", 144];
	~countOffWidth = 300;
	~countOffButtonsAcross = 4;
	~countOffGap = 4;
	~countNumberHeight = 150;
	~countNumberWidth = 240;	// approx golden ratio? why not
	~maxBeats = 8;
	~windowHeight = 800;
	
	~background = Color.clear;
	~flashBackground = Color.clear;
	~countNumberBack = Color.new255(255, 253, 196);
	~countNumberFlashBack = Color.new255(104, 0, 0);
	~countNumberColor = Color.black;
	~countNumberFlash = Color.white;

	~metroLevelDefault = 10;	// I should put this in the model but I'll deal with that later
	~metroSpec = #[1, 20, \exp, 0.1].asSpec;

//	~background = Color.white;
//	~flashBackground = Color.white;
	
	~prep = {// |model|
			// 'model' is the sectionSequencer represented by this gui
//		~model = model;
			// must receive notifications of status change:
			//	play/stop
			//	advancing to next section
		~model.addDependant(currentEnvironment);
		
		~window = ResizeFlowWindow("Control panel", Rect(50, 50, 800, ~windowHeight),
			scroll: false);
		
			// split window
		~leftFlow = FlowView(~window, 300@(~windowHeight - 4));
//		~rightFlow = FlowView(~window, ~countOffWidth@(~windowHeight - 4));
		~rightComp = GUI.compositeView.new(~window, Rect(0, 0, ~countOffWidth, ~windowHeight - 4));
//			.relativeOrigin_(false);
		
//		GUI.staticText.new(~rightFlow, (~countOffWidth-4)@40).background_(Color.blue(alpha: 0.2));
		
		~buildTransports.(~leftFlow);
		// ~buildCountoff.(~rightComp);
		// ~buildCountMenu.(~rightComp);
		// ~buildTempoControl.(~rightComp);

/*		
			// temp for Sept. 13 performance
		~recButton = Button(~rightComp, Rect(0, ~tempoCtl.bounds.bottom + ~countOffGap,
				~countOffWidth, ~menuHeight))
			.states_([["Prepare record", "Start record", "Stop record"],
				Color.black, Color.white].flop)
			.font_(Font(*~menuFontSpec))
			.action_({ |rb|
				switch(rb.value)
					{ 1 } {
						~path = "/Users/dewdrop/Music/SuperCollider Recordings/vln-sep-13/";
						~stamp = Date.getDate.stamp;
						fork {
							SynthDef(\quickdirtyrecorder, { |mainIn = 0, vlnIn,
									mainbuf, vlnbuf|
								var	main = In.ar(mainIn, 2),
									vln = In.ar(vlnIn, 2);
								DiskOut.ar(mainbuf, main - vln);
								DiskOut.ar(vlnbuf, In.ar(8, 1));
							}).memStore;
							~mainBuf ?? { ~mainBuf = Buffer.alloc(s, 65536 * 4, 2) };
							~vlnBuf ?? { ~vlnBuf = Buffer.alloc(s, 65536 * 4, 1) };
							s.sync;
							~mainBuf.write("%main%.aiff".format(~path, ~stamp),
								leaveOpen: true);
							~vlnBuf.write("%vln%.aiff".format(~path, ~stamp),
								leaveOpen: true);
							s.sync;
							~recNode = Synth.newPaused(\quickdirtyrecorder, [
								mainIn: 0, vlnIn: BP(\onsetRecorder).chan.inbus,
								mainbuf: ~mainBuf, vlnbuf: ~vlnBuf
							], RootNode(s), addAction: \addToTail);
							"\n\nReady to record.".postln;
						};
					}
					{ 2 } {
						~recNode.run(true);
					}
					{ 0 } {
						~recNode.free;
						~mainBuf.close; ~vlnBuf.close;
						~mainBuf.free; ~vlnBuf.free;
						~mainBuf = ~vlnBuf = ~recNode = nil;
					};
			});
*/		
		~fixRightComp.(~rightComp);
		
		~refreshSections.();
		
		~window.recursiveResize.front
			.onClose_(e { BP(~collIndex).free });

		// ~model.metroLevel ?? { ~model.metroLevel = ~metroLevelDefault };

		currentEnvironment
	};
	
	~buildTransports = { |parent|
			// * numAcross + (4 * (numAcross-1))
		~bigButtonSize = ~smallButtonSize * 3 + 8;

		~playButton = PR(\playPauseButton).copy
			.playingBackground_(Color.new255(169, 255, 163))
			.prep(parent, ~bigButtonSize@~bigButtonSize)
			.userAction_(e { |buttonProto|
				if(buttonProto.showingPlay) {
					~model.play;
				} {
					~model.stop;
				};
			});
		~toStartButton = PR(\gotoBeginningButton).copy.prep(parent, ~smallButtonSize@~smallButtonSize)
			.action_(e {
				~model.gotoSection(0);
			});
		~backSection = PR(\backOneSectionButton).copy.prep(parent, ~smallButtonSize@~smallButtonSize)
			.action_(e {
				~model.gotoSection(max(0, ~model.currentSection - 1));
			});
		~fwdSection = PR(\fwdOneSectionButton).copy.prep(parent, ~smallButtonSize@~smallButtonSize)
			.action_(e {
				~model.gotoSection(min(~model.currentSection + 1, ~model.sections.size - 1));
			});
		~sectionMenu = GUI.popUpMenu.new(parent, ~bigButtonSize@~menuHeight)
			.font_(GUI.font.new(*~menuFontSpec))
			.background_(Color.white)
			.action_(e { |view|
				~model.gotoSection(view.value);
			});
		~nextCueText = StaticText(parent, ~bigButtonSize@~menuHeight)
			.font_(GUI.font.new(*~menuFontSpec))
			.background_(Color.yellow(1.8))
			.align_(\center);
		~clearAllButton = Button(parent, ~bigButtonSize@~menuHeight)
			.font_(GUI.font.new(*~menuFontSpec))
			.states_([["Unload all segments", Color.black, ~playButton.background]])
			.action_(e {
				if(~model.isRunning) {
					"Do not unload while playing!!".postln;
				} {
					fork {
						"Unloading...".postln;
						~model.sections.do { |sect| sect.prUnload };
						1.0.wait;
						"Loading current segment resources...".postln;
						~model.loadResources(~model.currentSection + 1);
					};
				};
			});
	};
	
	~refreshSections = {
		if(~model.notNil) {
			{	~sectionMenu.items_(~model.sections.collect(_.name))
					.value_(~model.currentSection);
				if(~model.isRunning) {
					~nextCueText.string_(~sectionMenu.items[~model.currentSection+1] ? "END");
				} {
					~nextCueText.string_("");
				}
			}.defer;
		};
	};
	
	~freeCleanup = {
		~model.removeDependant(currentEnvironment);
		BP(~collIndex).releaseDependants;	// clear from global dependants dict
		~window.onClose_(nil).close;
		~userfree.();
	};
	
	~showPlaying = { |bool|
		defer(e {
			~playButton.currentState = bool.binaryValue;
			[~clearAllButton/*, ~toStartButton, ~backSection, ~fwdSection*/].do { |button|
				button.enabled = bool.not;
			};
		});
	};
	
	~update = { |obj, what, modifier|	// ... args ?
		switch(what)
			{ \play } {
				~showPlaying.(true);
				~nextCueText.string_(~sectionMenu.items[~model.currentSection+1] ? "END");
			}
			{ \stop } {
				~showPlaying.(false);
				~nextCueText.string_("");
			}
			{ \section } {
				defer(e {
					~sectionMenu.value = modifier;
					if(~model.isRunning) {
						~nextCueText.string_(~sectionMenu.items[modifier+1] ? "END");
					} {
						~nextCueText.string_("");
					};
				});
			}
			{ \autoReset } {
				defer(e { ~autoResetToggle.currentState = modifier });
			};
	};
}) => PR(\transports);

} {
	AbstractChuckArray.defaultSubType = savetype;
};
