/**
 * Copyright 2011 John Moore, Scott Gilroy
 *
 * This file is part of CollaboRhythm.
 *
 * CollaboRhythm is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later
 * version.
 *
 * CollaboRhythm is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with CollaboRhythm.  If not, see
 * <http://www.gnu.org/licenses/>.
 */
package collaboRhythm.workstation.controller
{

    import collaboRhythm.core.controller.ApplicationControllerBase;
    import collaboRhythm.shared.model.Account;
    import collaboRhythm.shared.view.CollaborationView;
    import collaboRhythm.workstation.model.settings.ComponentLayout;
    import collaboRhythm.workstation.model.settings.WindowSettings;
    import collaboRhythm.workstation.model.settings.WindowSettingsDataStore;
    import collaboRhythm.workstation.model.settings.WindowState;
    import collaboRhythm.workstation.view.ActiveAccountView;
    import collaboRhythm.workstation.view.ActiveRecordView;
    import collaboRhythm.workstation.view.PrimaryWindowView;
    import collaboRhythm.workstation.view.SecondaryWindowView;
    import collaboRhythm.workstation.view.TiledWidgetsContainerView;
    import collaboRhythm.workstation.view.WorkstationWindow;
    import collaboRhythm.workstation.view.spaces.CenterSpace;
    import collaboRhythm.workstation.view.spaces.LeftSpace;
    import collaboRhythm.workstation.view.spaces.RightSpace;
    import collaboRhythm.workstation.view.spaces.TopSpace;

    import flash.desktop.NativeApplication;
    import flash.display.DisplayObject;
    import flash.display.DisplayObjectContainer;
    import flash.display.NativeWindow;
    import flash.display.Screen;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.ui.Keyboard;

    import mx.containers.DividedBox;
    import mx.core.IUIComponent;
    import mx.core.IVisualElement;
    import mx.core.IVisualElementContainer;
    import mx.core.UIComponent;

    /**
	 * Top level controller for the whole application. Responsible for creating and managing the windows of the application. 
	 */
	public class WorkstationApplicationController extends ApplicationControllerBase
	{
        private var _windows:Vector.<WorkstationWindow> = new Vector.<WorkstationWindow>();
		private var _primaryWindow:WorkstationWindow;
        private var _primaryWindowView:PrimaryWindowView;
        private var _secondaryWindowView:SecondaryWindowView;
        private var _collaborationView:CollaborationView = new CollaborationView();
        private var _activeRecordView:ActiveRecordView;
        private var _widgetsContainerView:TiledWidgetsContainerView;
        private var _workstationAppControllersMediator:WorkstationAppControllersMediator;
		private var _topSpace:TopSpace;
		private var _centerSpace:CenterSpace;
		private var _leftSpace:LeftSpace;
		private var _rightSpace:RightSpace;
		private var _fullContainer:IVisualElementContainer;
		private var _widgetsContainer:IVisualElementContainer;
		private var _scheduleWidgetContainer:IVisualElementContainer;
		private var _fullScreen:Boolean = true;
		private var _zoom:Number = 0;
		private var _resetingWindows:Boolean = false;

        [Embed("/resources/settings.xml", mimeType="application/octet-stream")]
        private var _applicationSettingsEmbeddedFile:Class;

        public function WorkstationApplicationController()
		{

		}

        public override function main():void
        {
            super.main();

            initializeWindows();
			_logger.info("Windows initialized");

            createSession();

			NativeApplication.nativeApplication.addEventListener(Event.EXITING, onExiting);
        }

        // handles the use of windowSettings to start the application the way it was closed if specified
        private function initializeWindows():void
		{
			var resetWindowSettings:Boolean = settings.resetWindowSettings;

			var windowSettings:WindowSettings;

			if (!resetWindowSettings)
			{
				windowSettings = readWindowSettings();
				resetWindowSettings = !validateWindowSettings(windowSettings);
			}

			if (resetWindowSettings)
				createWindowsForScreens();
			else
				createWindows(windowSettings);
		}

        // The workstation application can use one or two screens, each screen needs a window
        // If the workstation uses two screens, the second screen is for the app widget views and for video recording and conferencing
        private function createWindowsForScreens():void
		{
            var primaryWindowView:PrimaryWindowView = createPrimaryWindowView(Screen.screens[0]);

            if (Screen.screens.length == 1 || settings.useSingleScreen)
            {
                _collaborationView.top = 0;
                _collaborationView.collaborationRoomView.bottom = 0;
                _collaborationView.recordVideoView.bottom = 0;
                _collaborationView.init(collaborationController, primaryWindowView.mainGroup);
                primaryWindowView.addElement(_collaborationView);
            }
            else
            {
                createSecondaryWindowView(Screen.screens[1]);
                _collaborationView.bottom = 0;
                _collaborationView.collaborationRoomView.top = 0;
                _collaborationView.recordVideoView.top = 0;
                _collaborationView.init(collaborationController, _secondaryWindowView.mainGroup);
                _secondaryWindowView.addElement(_collaborationView);
            }
		}

        // TODO: fix creating windows from settings
		private function createWindows(windowSettings:WindowSettings):void
		{
			for each (var windowState:WindowState in windowSettings.windowStates)
			{
				var window:WorkstationWindow = createWorkstationWindow();
				window.initializeForWindowState(windowState);
//				layoutComponentsFromSettings(windowState.componentLayouts, window);
			}
			fullScreen = windowSettings.fullScreen;
			zoom = windowSettings.zoom;
		}

        // TODO: fix validating window settings
		private function validateWindowSettings(windowSettings:WindowSettings):Boolean
		{
			return (windowSettings == null || windowSettings.windowStates.length == 0);
		}

        // creates a workstationWindow for one of the screens
		public function createWorkstationWindow():WorkstationWindow
		{
			var workstationWindow:WorkstationWindow = new WorkstationWindow();
			workstationWindow.addEventListener(Event.CLOSING, window_closingHandler);
			workstationWindow.fullScreenEnabled = _fullScreen;
			_windows.push(workstationWindow);
			return workstationWindow;
		}

        // creates the primary window view for the main screen, this window is always created
        private function createPrimaryWindowView(screen:Screen):PrimaryWindowView
        {
            var primaryWindow:WorkstationWindow = createWorkstationWindow();
            primaryWindow.initializeForScreen(screen);
            initializeWindowCommon(primaryWindow);
            _primaryWindowView = new PrimaryWindowView();
            _primaryWindowView.init(this, _activeAccount);
            primaryWindow.addElement(_primaryWindowView);
            return _primaryWindowView;
        }

        // creates the secondary window view, which is only used if more than one screen is available and the
        // useSingleScreen setting is false
        private function createSecondaryWindowView(screen:Screen):void
        {
            var secondaryWindow:WorkstationWindow = createWorkstationWindow();
            secondaryWindow.initializeForScreen(screen);
            initializeWindowCommon(secondaryWindow);
            _secondaryWindowView = new SecondaryWindowView();
            secondaryWindow.addElement(_secondaryWindowView);
        }

        // an eventListener can only be added to the stage after the window is initialized
        public function initializeWindowCommon(workstationWindow:WorkstationWindow):void
		{
			workstationWindow.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		}

        // called when a record is opened
        // a record may be opened based on user interaction or automatically for the primaryRecord of the activeAccount
        // when the application is in patient mode
        public override function openRecordAccount(recordAccount:Account):void
        {
            super.openRecordAccount(recordAccount);

            _activeRecordView = new ActiveRecordView();
            _activeRecordView.init(this, recordAccount);
            _primaryWindowView.mainGroup.addElement(_activeRecordView);

            // the widget views are loaded in a different location depending on whether one or two screens are being used
            if (Screen.screens.length == 1 || settings.useSingleScreen)
            {
                _widgetsContainerView = new TiledWidgetsContainerView();
                _widgetsContainerView.left = 0;
                _widgetsContainerView.right = 0;
                _widgetsContainerView.top = ActiveAccountView.ACTIVE_ACCOUNT_HEADER_HEIGHT;
                _widgetsContainerView.height = 210;
                _activeRecordView.fullViewGroup.top = 210 + ActiveAccountView.ACTIVE_ACCOUNT_HEADER_HEIGHT;
                _activeRecordView.addElement(_widgetsContainerView);
            }
            else
            {
                _widgetsContainerView = new TiledWidgetsContainerView();
                _widgetsContainerView.left = 0;
                _widgetsContainerView.right = 0;
                _widgetsContainerView.top = 0;
                _widgetsContainerView.bottom = 0;
                _secondaryWindowView.mainGroup.addElement(_widgetsContainerView);
            }
        }

        // the apps are not actually loaded immediately when a record is opened
        // only after the active record view has been created are they loaded, this makes the UI more responsive
        public function activeRecordView_creationCompleteHandler(recordAccount:Account):void
        {
            _workstationAppControllersMediator = new WorkstationAppControllersMediator(_widgetsContainerView.widgetsContainer, _widgetsContainerView.widgetsContainer, _activeRecordView.fullViewGroup, _settings, _componentContainer);
            _workstationAppControllersMediator.createAndStartApps(_activeAccount, recordAccount);
            // TODO: Rethink document retrieval
            recordAccount.primaryRecord.getDocuments();
        }

        // when a record is clased, all of the apps need to be closed and the documents cleared from the record
        public override function closeRecordAccount(recordAccount:Account):void
        {
            _workstationAppControllersMediator.closeApps();
			if (recordAccount)
                // TODO: clear the documents from a closed recordAccount
//				recordAccount.clearDocuments();
            _primaryWindowView.mainGroup.removeElement(_activeRecordView);
            if (!(Screen.screens.length == 1 || settings.useSingleScreen))
            {
                _secondaryWindowView.mainGroup.removeElement(_widgetsContainerView);
            }
        }

        protected override function changeDemoDate():void
        {
            if (_activeRecordAccount != null)
				_workstationAppControllersMediator.reloadUserData();

			//			user.demographics.dispatchEvent(new PropertyChangeEvent(PropertyChangeEvent.PROPERTY_CHANGE, false, false, PropertyChangeEventKind.UPDATE, "age", 0, user.demographics.age));
			_activeRecordAccount.primaryRecord.demographics.dispatchAgeChangeEvent();
        }

        public function showRecordVideoView():void
        {
            collaborationController.showRecordVideoView();
        }

        public function hideRecordVideoView():void
        {
            collaborationController.hideRecordVideoView();
        }

        public override function get currentFullView():String
        {
            return _workstationAppControllersMediator.currentFullView;
        }

        public override function get collaborationView():CollaborationView
        {
            return _collaborationView;
        }

        public override function get widgetsContainer():IVisualElementContainer
		{
			return _widgetsContainer;
		}

		public override function get scheduleWidgetContainer():IVisualElementContainer
		{
			return _scheduleWidgetContainer;
		}

		public override function get fullContainer():IVisualElementContainer
		{
			return _fullContainer;
		}

		public function get primaryWindow():WorkstationWindow
		{
			return _primaryWindow;
		}

        public function get zoom():Number
		{
			return _zoom;
		}

		public function set zoom(value:Number):void
		{
			_zoom = value;
			applyZoom();
		}

		private function changeZoom(zoomDelta:Number):void
		{
			zoom += zoomDelta;
		}

		private function applyZoom():void
		{
//			var scale:Number = 1 + (0.1 * _zoom * Math.abs(_zoom));
			var scale:Number;

			if (isNaN(_zoom))
				scale = 1;
			else if (_zoom == -7)
			{
				scale = 2.0 / 3;
			}
			else
			{
				scale = 1 + (0.05 * _zoom);
			}

			for each (var window:WorkstationWindow in _windows)
			{
				for (var i:int = 0; i < window.numElements; i++)
				{
					var child:IUIComponent = window.getElementAt(i) as IUIComponent;
					if (child != null)
					{
						child.scaleX = scale;
						child.scaleY = scale;
					}
				}
			}
		}

        public function get fullScreen():Boolean
		{
			return _fullScreen;
		}

		public function set fullScreen(value:Boolean):void
		{
			_fullScreen = value;

			for each (var window:WorkstationWindow in _windows)
			{
				window.fullScreenEnabled = _fullScreen;
			}
		}

		public function window_closingHandler(event:Event):void
		{
			//			trace("onClosing for " + this.toString());

			if (!_resetingWindows)
			{
				// Exit the application when any window is closed.
				// Note that we dispatch an exiting event but not a window closing event.
				// The exiting event handler will take care of any saving and cleanup operations.
				var exitingEvent:Event = new Event(Event.EXITING, false, true);
				NativeApplication.nativeApplication.dispatchEvent(exitingEvent);
				if (!exitingEvent.isDefaultPrevented())
				{
					NativeApplication.nativeApplication.exit();
				}
			}
		}

        // Close the entire application, sending out an event to any processes that might want to interrupt the closing
		private function applicationExit():void
		{
			var exitingEvent:Event = new Event(Event.EXITING, false, true);
			NativeApplication.nativeApplication.dispatchEvent(exitingEvent);
			if (!exitingEvent.isDefaultPrevented())
			{
				NativeApplication.nativeApplication.exit();
			}
		}

		// Close each of the windows in the application, and do any cleanup for the application after that
		private function onExiting(exitingEvent:Event):void
		{
			for each (var window:NativeWindow in NativeApplication.nativeApplication.openedWindows)
			{
				window.close();
			}

//			_collaborationMediator.cancelAllCollaborations();
			saveWindowSettings();
		}

//		public function get topSpace():TopSpace
//		{
//			return _topSpace;
//		}
//
//		public function get resetingWindows():Boolean
//		{
//			return _resetingWindows;
//		}
//
//		public function set resetingWindows(value:Boolean):void
//		{
//			_resetingWindows = value;
//		}
//
//		public function get windows():Vector.<WorkstationWindow>
//		{
//			return _windows;
//		}
//
//		public function set windows(value:Vector.<WorkstationWindow>):void
//		{
//			_windows = value;
//		}
//
//		public function get workstationCommandBarView():WorkstationCommandBarView
//		{
//			return _topSpace.topBar.workstationCommandBarView;
//		}
//
//		public override function get remoteUsersView():RemoteUsersListView
//		{
//			return _centerSpace.remoteUsersView;
//		}
//
//		public override function get collaborationRoomView():CollaborationRoomView
//		{
//			return _collaborationView.collaborationRoomView;
//		}
//
//		public override function get recordVideoView():RecordVideoView
//		{
//			return _collaborationView.recordVideoView;
//		}
//
//		private function resetWindows():void
//		{
//			// TODO: reset but preserve all existing spaces/components (move them instead of recreating them)
//
//			settings.resetWindowSettings = true;
//			_resetingWindows = true;
//			for each (var window:WorkstationWindow in _windows)
//			{
//				window.close();
//			}
//			_resetingWindows = false;
//
//			_windows = new Vector.<WorkstationWindow>();
//			_primaryWindow = null;
//			_topSpace = null;
//			_centerSpace = null;
//			_leftSpace = null;
//			_rightSpace = null;
//			_fullContainer = null;
//			_widgetsContainer = null;
//
//			initializeWindows();
//		}
//


		
//		private function addTopSpace(window:WorkstationWindow):void
//		{
//			if (_topSpace != null)
//				throw new Error("topSpace was already initialized when trying to add a new topSpace");
//
//			_topSpace = new TopSpace();
//			_topSpace.id = "topSpace";
//			_widgetsContainer = _topSpace.widgetsContainer;
//			_scheduleWidgetContainer = _topSpace.scheduleWidgetContainer;
//			window.addSpace(_topSpace);
//
//			_primaryWindow = window;
//		}
//
//		private function addCenterSpace(window:WorkstationWindow):void
//		{
//			if (_centerSpace != null)
//				throw new Error("centerSpace was already initialized when trying to add a new centerSpace");
//
//			_centerSpace = new CenterSpace();
//			_centerSpace.id = "centerSpace";
//			_fullContainer = _centerSpace.fullContainer;
//			window.addSpace(_centerSpace);
//		}
//
//		private function addLeftSpace(window:WorkstationWindow):void
//		{
//			if (_leftSpace != null)
//				throw new Error("leftSpace was already initialized when trying to add a new leftSpace");
//
//			_leftSpace = new LeftSpace();
//			_leftSpace.id = "leftSpace";
//			window.addSpace(_leftSpace);
//		}
//
//		private function addRightSpace(window:WorkstationWindow):void
//		{
//			if (_rightSpace != null)
//				throw new Error("rightSpace was already initialized when trying to add a new rightSpace");
//
//			_rightSpace = new RightSpace();
//			_rightSpace.id = "rightSpace";
//			window.addSpace(_rightSpace);
//		}
//
//		private function addSingleWindowSpaceCombination(window:WorkstationWindow):void
//		{
//			if (_rightSpace != null)
//				throw new Error("rightSpace was already initialized when trying to add a new rightSpace");
//			if (_leftSpace != null)
//				throw new Error("leftSpace was already initialized when trying to add a new leftSpace");
//			if (_centerSpace != null)
//				throw new Error("centerSpace was already initialized when trying to add a new centerSpace");
//			if (_topSpace != null)
//				throw new Error("topSpace was already initialized when trying to add a new topSpace");
//
//			var combination:SingleWindowSpaceCombination = new SingleWindowSpaceCombination();
//			combination.id = "singleWindowSpaceCombination";
//			window.addSpace(combination);
//
//			_topSpace = combination.topSpace;
//			_centerSpace = combination.centerSpace;
////			_leftSpace = combination.leftSpace;
////			_rightSpace = combination.rightSpace;
//			_widgetsContainer = _topSpace.widgetsContainer;
//			_scheduleWidgetContainer = _topSpace.scheduleWidgetContainer;
//			_fullContainer = _centerSpace.fullContainer;
//		}
		
		private function onKeyUp(event:KeyboardEvent):void 
		{
			// If the user presses escape, close the entire application
			if (event.keyCode == Keyboard.ESCAPE)
			{
				applicationExit();
			}
			else if (event.keyCode == Keyboard.F11)
			{
				fullScreen = !fullScreen;
			}
			if (event.ctrlKey && !event.altKey)
			{
				if (event.keyCode == Keyboard.EQUAL)
				{
					changeZoom(1);
				}
				else if (event.keyCode == Keyboard.MINUS)
				{
					changeZoom(-1);
				}
				else if (event.keyCode == Keyboard.NUMBER_0)
				{
					zoom = 0;
				}
				else if (event.keyCode == Keyboard.L)
				{
					testLogging();
				}
				else if (event.keyCode == Keyboard.F5)
				{
					reloadPlugins();
				}
			}
			else if (event.ctrlKey && event.altKey)
			{
				if (event.keyCode == Keyboard.NUMBER_0)
				{
					zoom = -7;
				}
				else if (event.keyCode == Keyboard.NUMBER_1)
				{
					_settings.useSingleScreen = true;
//					resetWindows();
				}
				else if (event.keyCode == Keyboard.NUMBER_2)
				{
					_settings.useSingleScreen = false;
//					resetWindows();
				}
			}
			else if (event.keyCode == Keyboard.F1)
			{
				useDemoPreset(0);
			}
			else if (event.keyCode == Keyboard.F2)
			{
				useDemoPreset(1);
			}
			else if (event.keyCode == Keyboard.F3)
			{
				useDemoPreset(2);
			}
			else if (event.keyCode == Keyboard.F4)
			{
				useDemoPreset(3);
			}
			else if (event.keyCode == Keyboard.F5)
			{
				targetDate = null;
			}
		}

		private function useDemoPreset(demoPresetIndex:int):void
		{
			if (_settings.demoDatePresets && _settings.demoDatePresets.length > demoPresetIndex)
				targetDate = _settings.demoDatePresets[demoPresetIndex];
		}

		private function saveWindowSettings():void
		{
			var windowSettings:WindowSettings = new WindowSettings();
			windowSettings.fullScreen = fullScreen;
			windowSettings.zoom = zoom;
			for each (var window:WorkstationWindow in _windows)
			{
				var windowState:WindowState = new WindowState();
				windowState.bounds = window.stage.nativeWindow.bounds;
				windowState.displayState = window.displayState;
				
				// Note that WindowState has no fullScreen property because
				// we track this property application-wide instead of on a per-window basis.
				
				for each (var component:UIComponent in window.spaces)
				{
					if (component.id != null)
					{
						windowState.spaces.push(component.id);
					}
				}
				
				addComponentLayoutsFromWindow(window, windowState.componentLayouts);
				
				windowSettings.windowStates.push(windowState);
			}
			
			var windowSettingsDataStore:WindowSettingsDataStore = new WindowSettingsDataStore();
			windowSettingsDataStore.saveWindowSettings(windowSettings);
		}
		
		private function addComponentLayoutsFromWindow(window:WorkstationWindow, componentLayouts:Vector.<ComponentLayout>):void
		{
			addComponentLayoutsFromContainerRecursive(window, componentLayouts);
		}

		private function addComponentLayoutsFromContainerRecursive(container:UIComponent, componentLayouts:Vector.<ComponentLayout>):void
		{
			// first add the ComponentLayout for this container if appropriate
			if (container != null && container.id != null && !isNaN(container.percentWidth) && !isNaN(container.percentHeight) && container.parent is DividedBox)
			{
				componentLayouts.push(new ComponentLayout(container.id, container.percentWidth, container.percentHeight));
			}
			
			// now act recursively on any children
			var displayObjectContainer:DisplayObjectContainer = container;
			var visualElementContainer:IVisualElementContainer = container as IVisualElementContainer;
			
			if (visualElementContainer != null)
			{
				for (i = 0; i < visualElementContainer.numElements; i++)
				{
					var visualElement:IVisualElement = visualElementContainer.getElementAt(i);
					addComponentLayoutsFromContainerRecursive(visualElement as UIComponent, componentLayouts);
				}
			}
			else if (displayObjectContainer != null)
			{
				for (var i:int = 0; i < displayObjectContainer.numChildren; i++)
				{
					var displayObject:DisplayObject = displayObjectContainer.getChildAt(i);
					addComponentLayoutsFromContainerRecursive(displayObject as UIComponent, componentLayouts);
				}
			}
		}
		
		private function layoutComponentsFromSettings(componentLayouts:Vector.<ComponentLayout>, window:WorkstationWindow):void
		{
			for each (var componentLayout:ComponentLayout in componentLayouts)
			{
				var component:UIComponent = findComponentById(window, componentLayout.id);
				if (component != null)
				{
					component.percentWidth = componentLayout.percentWidth;
					component.percentHeight = componentLayout.percentHeight;
				}
			}
		}
		
		private function findComponentById(window:WorkstationWindow, id:String):UIComponent
		{
			return findComponentByIdRecursive(window, id);
		}
		
		private function findComponentByIdRecursive(container:UIComponent, id:String):UIComponent
		{
			// first see if we have a match
			if (container != null && container.id != null && container.id == id)
			{
				return container;
			}
			
			// now act recursively on any children
			var displayObjectContainer:DisplayObjectContainer = container;
			var visualElementContainer:IVisualElementContainer = container as IVisualElementContainer;
			
			if (visualElementContainer != null)
			{
				for (i = 0; i < visualElementContainer.numElements; i++)
				{
					var visualElement:IVisualElement = visualElementContainer.getElementAt(i);
					var foundComponent:UIComponent = findComponentByIdRecursive(visualElement as UIComponent, id);
					if (foundComponent != null)
						return foundComponent;
				}
			}
			else if (displayObjectContainer != null)
			{
				for (var i:int = 0; i < displayObjectContainer.numChildren; i++)
				{
					var displayObject:DisplayObject = displayObjectContainer.getChildAt(i);
					foundComponent = findComponentByIdRecursive(displayObject as UIComponent, id);
					if (foundComponent != null)
						return foundComponent;
				}
			}
			
			return null;
		}

		private function readWindowSettings():WindowSettings
		{
			var windowSettingsDataStore:WindowSettingsDataStore = new WindowSettingsDataStore();
			var windowSettings:WindowSettings = windowSettingsDataStore.readWindowSettings();
			return windowSettings;
		}

        public override function get applicationSettingsEmbeddedFile():Class
        {
            return _applicationSettingsEmbeddedFile;
        }
    }
}
